import time
import calendar
from datetime import datetime
from bartendro import app, db
from flask import Flask, request, render_template
from flask_login import login_required
from sqlalchemy import text, column

MONTH_NAMES = ['', 'January', 'February', 'March', 'April', 'May', 'June',
               'July', 'August', 'September', 'October', 'November', 'December']


@app.route('/admin/stats')
@login_required
def stats_index():
    # Query to get drink counts grouped by year and month
    monthly_stats_raw = db.session.query(column("year"), column("month"), column("drink_count"), column("total_volume"))\
                 .from_statement(text("""SELECT 
                                            strftime('%Y', datetime(drink_log.time, 'unixepoch')) as year,
                                            strftime('%m', datetime(drink_log.time, 'unixepoch')) as month,
                                            count(*) as drink_count,
                                            sum(drink_log.size) as total_volume
                                           FROM drink_log 
                                       GROUP BY year, month
                                       ORDER BY year DESC, month DESC""")).all()

    # Convert month numbers to names
    monthly_stats = []
    for year, month, drink_count, total_volume in monthly_stats_raw:
        month_name = MONTH_NAMES[int(month)]
        monthly_stats.append((year, month_name, drink_count, total_volume))

    # Prepare chart data for the last 3 years
    current_year = datetime.now().year
    years = [current_year, current_year - 1, current_year - 2]
    
    # Create a dict for quick lookup: {(year, month): drink_count}
    stats_dict = {}
    for year, month, drink_count, total_volume in monthly_stats_raw:
        stats_dict[(int(year), int(month))] = drink_count
    
    # Build chart data: list of 12 values for each year
    chart_data = {}
    for year in years:
        chart_data[year] = [stats_dict.get((year, m), 0) for m in range(1, 13)]

    return render_template("admin/stats",
                           options=app.options,
                           title="Drink Statistics",
                           monthly_stats=monthly_stats,
                           chart_data=chart_data,
                           chart_years=years)
