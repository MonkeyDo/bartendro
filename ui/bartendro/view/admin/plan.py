from sqlalchemy import func, asc
from bartendro import app, db
from flask import Flask, request, redirect, render_template, jsonify
from flask_login import login_required
from bartendro.model.booze import Booze
from bartendro.model.dispenser import Dispenser
from bartendro.planner import start_planning, stop_planning, get_planning_status
from operator import itemgetter


@app.route('/admin/plan')
@login_required
def plan():
    driver = app.driver
    count = driver.count()

    # Get list of boozes sorted by name
    boozes = db.session.query(Booze).order_by(asc(func.lower(Booze.name))).all()
    booze_list = [(0, "-- Select a booze --")] + [(b.id, b.name) for b in boozes]

    # Calculate min and max locked boozes
    min_locked = 2
    max_locked = count - 2

    return render_template("admin/plan",
                           title="Plan Dispensers",
                           booze_list=booze_list,
                           count=count,
                           min_locked=min_locked,
                           max_locked=max_locked,
                           options=app.options)


@app.route('/admin/plan/start', methods=['POST'])
@login_required
def plan_start():
    """Start the genetic algorithm planner."""
    data = request.get_json()
    num_dispensers = data.get('num_dispensers', 8)
    locked_boozes = data.get('locked_boozes', [])
    blocked_boozes = data.get('blocked_boozes', [])
    
    result = start_planning(num_dispensers, locked_boozes, blocked_boozes)
    return jsonify(result)


@app.route('/admin/plan/stop', methods=['POST'])
@login_required
def plan_stop():
    """Stop the genetic algorithm planner."""
    result = stop_planning()
    return jsonify(result)


@app.route('/admin/plan/status')
@login_required
def plan_status():
    """Get the current status of the planner."""
    status = get_planning_status()
    
    # Add booze names to the solution for display
    if status['best_solution']:
        booze_names = {}
        boozes = db.session.query(Booze.id, Booze.name).all()
        for booze_id, name in boozes:
            booze_names[booze_id] = name
        
        status['solution_names'] = [booze_names.get(b, 'Unknown') for b in status['best_solution']]
    else:
        status['solution_names'] = []
    
    return jsonify(status)


@app.route('/admin/plan/drinks', methods=['POST'])
@login_required
def plan_drinks():
    """Get the list of drinks that can be made with the given booze selection."""
    from sqlalchemy import text
    from bartendro.model.drink import Drink
    from bartendro.model.booze import Booze
    
    data = request.get_json()
    booze_ids = data.get('booze_ids', [])
    
    if not booze_ids:
        return jsonify({'drinks': []})
    
    try:
        # Get booze names lookup
        booze_names = {}
        for booze in db.session.query(Booze).all():
            booze_names[booze.id] = booze.name
        
        # Get all drinks and their required boozes using raw SQL
        # Note: drink name is in drink_name table, not drink table
        result = db.session.execute(text("""SELECT d.id, dn.name, db.booze_id
                                              FROM drink d
                                              JOIN drink_name dn ON d.name_id = dn.id
                                              JOIN drink_booze db ON db.drink_id = d.id
                                             WHERE d.available = 1
                                          ORDER BY dn.name, db.booze_id"""))
        
        # Build dict of drink -> required boozes
        drink_reqs = {}
        drink_names = {}
        drink_booze_ids = {}  # drink_id -> list of booze_ids
        for row in result:
            drink_id = row[0]
            drink_name = row[1]
            booze_id = row[2]
            if drink_id not in drink_reqs:
                drink_reqs[drink_id] = set()
                drink_names[drink_id] = drink_name
                drink_booze_ids[drink_id] = []
            drink_reqs[drink_id].add(booze_id)
            drink_booze_ids[drink_id].append(booze_id)
        
        # Find drinks that can be made
        available_boozes = set(booze_ids)
        can_make = []
        for drink_id, required in drink_reqs.items():
            if required.issubset(available_boozes):
                # Get booze names for this drink
                boozes_str = ', '.join([booze_names.get(bid, 'Unknown') for bid in sorted(drink_booze_ids[drink_id])])
                can_make.append({
                    'id': drink_id, 
                    'name': drink_names[drink_id],
                    'boozes': boozes_str
                })
        
        # Sort by name
        can_make.sort(key=lambda x: x['name'])
        
        return jsonify({'drinks': can_make})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'drinks': [], 'error': str(e)})
