from sqlalchemy import func, asc, or_
from operator import itemgetter
from bartendro import app, db
from flask import Flask, request, redirect, render_template
from flask_login import login_required
from bartendro.model.drink import Drink
from bartendro.model.booze import Booze
from bartendro.model.dispenser import Dispenser
from bartendro.model.drink_booze import DrinkBooze
from bartendro.model.drink_name import DrinkName


@app.route('/admin/drink')
@app.route('/admin/drink/<int:drink_id>')
@login_required
def admin_drink_new(drink_id=None):
    drink_search = request.args.get('q', '').strip()
    drink_query = db.session.query(Drink).join(DrinkName).filter(Drink.name_id == DrinkName.id)
    if drink_search:
        search_term = '%%%s%%' % drink_search
        drink_query = drink_query.outerjoin(DrinkBooze, Drink.id == DrinkBooze.drink_id) \
                               .outerjoin(Booze, DrinkBooze.booze_id == Booze.id) \
                               .filter(or_(DrinkName.name.ilike(search_term), Booze.name.ilike(search_term))) \
                               .distinct()
    drinks = drink_query.order_by(asc(func.lower(DrinkName.name))).all()

    boozes = db.session.query(Booze).order_by(asc(func.lower(Booze.name))).all()
    booze_list = [(b.id, b.name) for b in boozes]
    dispensers = db.session.query(Dispenser).order_by(Dispenser.id).all()
    return render_template("admin/drink",
                           options=app.options,
                           title="Drinks",
                           booze_list=booze_list,
                           drinks=drinks,
                           drink_search=drink_search,
                           dispensers=dispensers,
                           count=app.driver.count(),
                           edit_drink_id=drink_id)
