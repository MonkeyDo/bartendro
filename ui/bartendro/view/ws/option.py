import json
import os
import sqlite3
import shutil
from time import time
from tempfile import mktemp
from sqlalchemy import asc, func
from bartendro import app, db, mixer
from flask import Flask, request
from flask_login import login_required, logout_user
from werkzeug.exceptions import InternalServerError, BadRequest
from sqlalchemy import text
from bartendro.model.option import Option
from bartendro.options import bartendro_options

DB_BACKUP_DIR = '.db-backups'
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
DB_FILE = os.path.join(BASE_DIR, "bartendro.db")
DB_BACKUP_DIR = os.path.join(BASE_DIR, DB_BACKUP_DIR)


def close_database_connections():
    # Flask-SQLAlchemy 3 does not expose a bound engine through db.session.bind.
    db.session.remove()
    db.engine.dispose()


@app.route('/ws/options', methods=["POST", "GET"])
@login_required
def ws_options():
    if request.method == 'GET':
        options = Option.query.order_by(asc(func.lower(Option.key)))
        data = {}
        for o in options:
            try:
                if isinstance(bartendro_options[o.key], int):
                    value = int(o.value)
                elif isinstance(bartendro_options[o.key], str):
                    value = str(o.value)
                elif isinstance(bartendro_options[o.key], boolean):
                    value = boolean(o.value)
                else:
                    raise InternalServerError
            except KeyError:
                pass

            data[o.key] = value

        return json.dumps({'options': data})

    if request.method == 'POST':
        try:
            data = request.json['options']
            logout = request.json['logout']
        except KeyError:
            raise BadRequest

        if logout: logout_user()

        Option.query.delete()

        for key in data:
            option = Option(key, data[key])
            db.session.add(option)

        db.session.commit()
        try:
            import uwsgi
            uwsgi.reload()
            reload = True
        except ImportError:
            reload = False
        return json.dumps({'reload': reload})

    raise BadRequest


@app.route('/ws/upload', methods=["POST"])
@login_required
def ws_upload():
    db_file = request.files['file']
    file_name = mktemp()
    try:
        db_file.save(file_name)
    except IOError:
        raise InternalServerError

    con = None
    try:
        con = sqlite3.connect(file_name)
        cur = con.cursor()
        cur.execute("SELECT * FROM dispenser")
    except sqlite3.DatabaseError:
        os.unlink(file_name)
        raise BadRequest
    finally:
        if con:
            con.close()

    return json.dumps('{ "file_name": "%s" }' % file_name)


@app.route('/ws/upload/confirm', methods=["POST"])
@login_required
def ws_upload_confirm():
    file_name = request.json['file_name']
    print(file_name)
    print("Move file '%s' into place." % file_name)

    if not os.path.exists(DB_BACKUP_DIR):
        try:
            os.mkdir(DB_BACKUP_DIR)
        except OSError:
            return json.dumps({'error': "Cannot create backup dir"})

    # close the connection to the database to flush anything that might still be in a cache somewhere
    close_database_connections()

    try:
        shutil.move(DB_FILE, os.path.join(DB_BACKUP_DIR, "%d.db" % int(time())))
    except OSError:
        return json.dumps({'error': "Cannot backup old database"})

    try:
        shutil.move(file_name, DB_FILE)
    except OSError:
        return json.dumps({'error': "Cannot backup old database"})

    mc = app.mc
    mc.delete("top_drinks")
    mc.delete("other_drinks")
    mc.delete("available_drink_list")
    return json.dumps({'error': ""})
