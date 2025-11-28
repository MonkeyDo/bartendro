import time
from bartendro import app, db
from sqlalchemy import desc, text
from flask import Flask, request, render_template
from flask_login import login_required
from bartendro.model.drink import Drink
from bartendro.model.drink_log import DrinkLog
from bartendro.model.booze import Booze
from bartendro.model.booze_group import BoozeGroup
from bartendro.form.booze import BoozeForm

DEFAULT_TIME = 12
display_info = {
    12: 'Drinks poured in the last 12 hours.',
    72: 'Drinks poured in the last 3 days.',
    168: 'Drinks poured in the last week.',
    0: 'All drinks ever poured'
}


@app.route('/trending')
def trending_drinks():
    return trending_drinks_detail(DEFAULT_TIME)


@app.route('/trending/<int:hours>')
def trending_drinks_detail(hours):

    title = "Trending drinks"
    
    try:
        txt = display_info[hours]
    except KeyError:
        txt = "Drinks poured in the last %d hours" % hours

    # Use current time as end date
    enddate = int(time.time())
    
    # if a number of hours is 0, then show for "all time"
    if hours:
        begindate = enddate - (hours * 60 * 60)
    else:
        begindate = 0

    total_number = db.session.query(text("number"))\
                 .from_statement(text("""SELECT count(*) as number
                                           FROM drink_log 
                                          WHERE drink_log.time >= :begin 
                                            AND drink_log.time <= :end"""))\
                 .params(begin=begindate, end=enddate).first()

    total_volume = db.session.query(text("volume"))\
                 .from_statement(text("""SELECT sum(drink_log.size) as volume 
                                           FROM drink_log 
                                          WHERE drink_log.time >= :begin 
                                            AND drink_log.time <= :end"""))\
                 .params(begin=begindate, end=enddate).first()

    top_drinks = db.session.query(text("id"), text("name"), text("number"), text("volume"))\
                 .from_statement(text("""SELECT drink.id, 
                                                drink_name.name,
                                                count(drink_log.drink_id) AS number, 
                                                sum(drink_log.size) AS volume 
                                           FROM drink_log
                                           JOIN drink ON drink_log.drink_id = drink.id
                                           JOIN drink_name ON drink.name_id = drink_name.id
                                          WHERE drink_log.time >= :begin AND drink_log.time <= :end 
                                       GROUP BY drink.id 
                                       ORDER BY count(drink_log.drink_id) desc;"""))\
                 .params(begin=begindate, end=enddate).all()

    return render_template("trending",
                           top_drinks=top_drinks,
                           options=app.options,
                           title="Trending drinks",
                           txt=txt,
                           total_number=total_number[0],
                           total_volume=total_volume[0],
                           hours=hours)
