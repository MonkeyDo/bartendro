from bartendro import app, db
from flask import Flask, request, jsonify
from flask_login import login_required
from werkzeug.exceptions import BadRequest
from bartendro.model.drink import Drink
from bartendro.model.booze import Booze
from bartendro.model.drink_booze import DrinkBooze
from bartendro.form.booze import BoozeForm
import json


@app.route('/ws/booze/match/<str>')
def ws_booze(request, str):
    str = str + "%%"
    boozes = db.session.query("id", "name").from_statement("SELECT id, name FROM booze WHERE name LIKE :s").params(s=str).all()
    return jsonify(boozes)


def check_booze_references(booze_id):
    """Check if a booze is referenced by drinks, dispensers, or booze groups."""
    from bartendro.model.dispenser import Dispenser
    from bartendro.model.booze_group import BoozeGroup
    
    # Check if this booze is used in any drinks
    drink_boozes = db.session.query(DrinkBooze).filter(DrinkBooze.booze_id == booze_id).all()
    if drink_boozes:
        drinks = []
        for db_entry in drink_boozes:
            drink = Drink.query.filter_by(id=db_entry.drink_id).first()
            if drink:
                drinks.append({
                    'id': drink.id,
                    'name': drink.name.name
                })
        return {
            'status': 'error',
            'reason': 'in_use',
            'drinks': drinks
        }
    
    # Check if this booze is assigned to a dispenser
    dispenser = Dispenser.query.filter_by(booze_id=booze_id).first()
    if dispenser:
        return {
            'status': 'error',
            'reason': 'assigned_to_dispenser',
            'dispenser': dispenser.id
        }
    
    # Check if this booze is an abstract booze for a group
    booze_group = BoozeGroup.query.filter_by(abstract_booze_id=booze_id).first()
    if booze_group:
        return {
            'status': 'error',
            'reason': 'is_abstract_booze',
            'group_name': booze_group.name if hasattr(booze_group, 'name') else 'unknown'
        }
    
    return None


@app.route('/ws/booze/<int:booze_id>/check', methods=["GET"])
@login_required
def ws_booze_check(booze_id):
    """Check if a booze can be deleted (not referenced by any drinks, dispensers, or groups)."""
    booze = Booze.query.filter_by(id=int(booze_id)).first()
    if not booze:
        raise BadRequest("Booze not found")
    
    refs = check_booze_references(booze_id)
    if refs:
        return json.dumps(refs), 409
    
    return json.dumps({'status': 'ok', 'can_delete': True})


@app.route('/ws/booze/<int:booze_id>/delete', methods=["POST"])
@login_required
def ws_booze_delete(booze_id):
    """Delete a booze if it's not referenced by any drinks."""
    from bartendro.model.booze_group_booze import BoozeGroupBooze
    from bartendro.model.shot_log import ShotLog
    
    booze = Booze.query.filter_by(id=int(booze_id)).first()
    if not booze:
        raise BadRequest("Booze not found")
    
    # Check references before deleting
    refs = check_booze_references(booze_id)
    if refs:
        return json.dumps(refs), 409
    
    try:
        # Delete booze_group_booze entries
        db.session.query(BoozeGroupBooze).filter(BoozeGroupBooze.booze_id == booze_id).delete()
        
        # Delete shot_log entries (or update to a placeholder - for now delete)
        db.session.query(ShotLog).filter(ShotLog.booze_id == booze_id).delete()
        
        # Delete the booze
        db.session.delete(booze)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        raise BadRequest(f"Failed to delete booze: {str(e)}")
    
    # Clear caches
    mc = app.mc
    mc.delete("top_drinks")
    mc.delete("other_drinks")
    mc.delete("available_drink_list")
    
    return json.dumps({'status': 'ok', 'id': booze_id})
