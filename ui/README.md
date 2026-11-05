The Bartendro UI requires the following pieces of software to be installed:

werkzeug - http://werkzeug.pocoo.org/docs/
jinja2 - http://jinja.pocoo.org/docs/
wtforms - http://wtforms.simplecodes.com/

If you're installing into raspian then you can get all the dependencies in one go:

apt-get install nginx uwsgi uwsgi-plugin-python
apt-get install python-werkzeug python-jinja2 python-setuptools \
        python-wtforms python-serial python-smbus python-sqlite python-sqlalchemy \
        memcached python-memcache python-rpi.gpio python-flask sqlite3 

If you'd like to have python dependencies installed with pip:

pip install flask flask-sqlalchemy wtforms python-memcached pyserial

Also you need to install flask-sqlalchemy & flask-login:

   https://pypi.python.org/packages/source/F/Flask-SQLAlchemy/Flask-SQLAlchemy-0.16.tar.gz
   https://pypi.python.org/packages/source/F/Flask-Login/Flask-Login-0.1.3.tar.gz

Starting Bartendro UI for the first time
========================================

Database
--------

To start Bartendro for the first time, you'll need to copy the bartendro.db.default
file to bartendro.db in the ui directory. This provides a clean database with all
the required tables for you to start playing with.

Configuration
-------------

You'll need to copy the config.py.default file to config.py . This will assume
the basic sane setting for your Bartendro configuration. These settings will be migrated
to the DB soon, so please take a look at the file to see what can be changed.

Starting
--------

Then, once you're ready, run:

   # sudo ./bartendro_server --debug

That should start the server on all interfaces on your machine. Bartendro's WiFi address is 
always 10.0.0.1 and the wired ethernet ip address is assigned by DHCP. To see the addresses
for Bartendro, see the Network Info box on the options page.

Software only mode
------------------

If you're running the code on anything but an RPI connected to full Bartendro hardware,
you'll need to do:

   # export BARTENDRO_SOFTWARE_ONLY=1

Otherwise the software will attempt to communicate with the hardware that isn't present
and fail. In the software only mode the bartendro UI will run an attempt to do everything
it can, short of actually communicating with the hardware. If you are running in
software only mode, you do no need to run the bartendro_server.py program under sudo. Sudo
rights are only needed to communicate with the hardware.

Debug logs
----------
Logs are written to `ui/logs/bartendro.log` and are rotated every day at 6AM,
so that a single session should be contained in one log file.
We keep the last 10 log files and automatically remove older ones.

Select **Debug** under **General options → Logging level** to include verbose logging
from pretty much every part of the application, so you can debug what the hell is going on.
It will include hardware communications, operation start/completion messages, state transitions,
serial/I²C diagnostics and webserver logs. With the standard startup scripts,

Tracing operations in logs
--------------------------

Application logs include a random operation ID, such as `[op=a1b2c3d4e5f6]`. This groups
messages from an instrumented operation (such as pouring a drink), including its
nested mixer and hardware calls. Search for the same ID to follow the operation
from request to completion or failure, even when other operations' logs are mixed
in. `[op=-]` means the message has no active operation context.

```sh
grep -F '[op=a1b2c3d4e5f6]' ui/logs/bartendro.log
```

Upgrade Existing DB
-------------------

For Bartendro software reboot (2023), use the following sqlite query to upgrade the DB
for support of the new liquid level calculations:

   alter table dispenser add column bottle_size INTEGER DEFAULT 0;
