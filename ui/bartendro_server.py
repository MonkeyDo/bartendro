#!/usr/bin/env python3

from bartendro import app
import logging
import logging.handlers
import os
import memcache
import sys
import argparse
import subprocess
import traceback
from datetime import time
from time import monotonic

from bartendro.global_lock import BartendroGlobalLock
from bartendro.router import driver
from bartendro import mixer
from bartendro.error import BartendroBrokenError, SerialIOError
from bartendro.options import load_options, configure_hardware_options
from bartendro.diagnostics import OperationFilter, WerkzeugLogFilter

RPI_CPU_IDS_FOR_TTYAMA0 = [
    "0002", "0003", "0004", "0005", "0006", "0007", "0008", "0009", "000d", "000e", "000f", "0010", "0013", "0011", "0012",
    "a01041", "a21041", "900092"
]
DEFAULT_SERIAL_DEVICE = "/dev/ttyS0"
LEGACY_SERIAL_DEVICE = "/dev/ttyAMA0"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


def determine_serial_device():

    try:
        f = open("/proc/cpuinfo", "r")
    except IOError:
        return DEFAULT_SERIAL_DEVICE

    for line in f.readlines():
        if line.startswith("Revision"):
            line = line.strip()
            ver = line[11:]
            if ver in RPI_CPU_IDS_FOR_TTYAMA0:
                f.close()
                return LEGACY_SERIAL_DEVICE

    f.close()
    return DEFAULT_SERIAL_DEVICE


if os.path.exists("version.txt"):
    with open("version.txt", "r") as f:
        version = f.read()
else:
   version = subprocess.check_output(["git", "rev-parse", "HEAD"])
   if version:
       version = "commit#" + str(version[:10], "utf-8")
   else:
    version = "[unknown]"

LOG_FILES_SAVED = 10  # number of daily log archives to retain

parser = argparse.ArgumentParser(description='Bartendro application process')
parser.add_argument("-d",
                    "--debug",
                    help="Turn on debugging mode to see stack traces in the error log",
                    default=True,
                    action='store_true')
parser.add_argument("-t", "--host", help="Which interfaces to listen on. Default: 127.0.0.1", default="127.0.0.1", type=str)
parser.add_argument("-p", "--port", help="Which port to listen on. Default: 8080", default="8080", type=int)
parser.add_argument("-s",
                    "--software-only",
                    help="Run only the server software, without hardware interaction.",
                    default=False,
                    action='store_true')

args = parser.parse_args()

try:
    import uwsgi
    have_uwsgi = True
except ImportError:
    have_uwsgi = False


def print_software_only_notice():
    print("""If you're trying to run this code without having Bartendro hardware,
you can still run the software portion of it in a simulation mode. In this mode no 
communication with the Bartendro hardware will happen to allow the software to run.
To enable this mode, set the BARTENDRO_SOFTWARE_ONLY environment variable to 1 and 
try again:

    > export BARTENDRO_SOFTWARE_ONLY=1

""")


# Set up logging
if not os.path.exists("logs"):
    os.mkdir("logs")

# Rotate at 6 AM local time so evening and overnight logs stay together across restarts.
handler = logging.handlers.TimedRotatingFileHandler(
    os.path.join("logs", "bartendro.log"),
    when='midnight',
    atTime=time(6, 0),
    backupCount=LOG_FILES_SAVED)
log_formatter = logging.Formatter(
    '%(asctime)s.%(msecs)03d %(levelname)s [%(name)s] [op=%(operation_id)s] %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%S')
logging.basicConfig(level=logging.INFO)
root_logger = logging.getLogger()
for console_handler in root_logger.handlers:
    console_handler.setFormatter(log_formatter)
    console_handler.addFilter(OperationFilter())
handler.setFormatter(log_formatter)
handler.addFilter(OperationFilter())
root_logger.addHandler(handler)
# Remap Werkzeug INFO to DEBUG before handlers apply their level thresholds.
logging.getLogger('werkzeug').addFilter(WerkzeugLogFilter())
logger = logging.getLogger('bartendro')
logger.info("Bartendro start up sequence:")

try:
    app.software_only = args.software_only or int(os.environ['BARTENDRO_SOFTWARE_ONLY'])
    app.num_dispensers = 8
except KeyError:
    app.software_only = 0

if not os.path.exists(os.path.join(BASE_DIR, "bartendro.db")):
    logger.error("Database missing: %s. Copy bartendro.db.default to this path.",
                 os.path.join(BASE_DIR, "bartendro.db"))
    sys.exit(-1)

# Apply the saved verbosity before hardware discovery begins.
try:
    with app.app_context():
        app.options = load_options(include_hardware=False)
except Exception:
    logger.exception("Startup failed while loading options")
    raise
logger.debug("Startup version=%s pid=%d cwd=%s database=%s log_file=%s level=%s software_only=%s",
             version.strip(), os.getpid(), os.getcwd(), os.path.join(BASE_DIR, "bartendro.db"),
             handler.baseFilename, app.options.log_level, bool(app.software_only))

# Create a memcache connection and flush everything
app.mc = memcache.Client(['127.0.0.1:11211'], debug=0)
logger.debug("Clearing memcache at 127.0.0.1:11211")
if not app.mc.flush_all():
    logger.error("Memcache flush failed at 127.0.0.1:11211")

# Create the Bartendro globals to prevent multiple people from using it at the same time.
app.globals = BartendroGlobalLock()

device = determine_serial_device()
logger.debug("Selected serial device: %s", device)

startup_err = ""
# Start the driver, which talks to the hardware
try:
    hardware_started = monotonic()
    app.driver = driver.RouterDriver(device, app.software_only)
    app.driver.open()
    logging.info("Found %d dispensers." % app.driver.count())
    logger.debug("Hardware initialization complete: device=%s elapsed_ms=%.1f",
                 device, (monotonic() - hardware_started) * 1000)
except BartendroBrokenError:
    logger.exception("Hardware startup failed: device=%s", device)
    err = "Cannot open I2C interface to a router board. If a router board is connected, please turn off Bartendro, wait 3 seconds and then turn back on."
    if have_uwsgi:
        startup_err = err
    else:
        print()
        print(err)
        print()
        print_software_only_notice()
        sys.exit(-1)
except SerialIOError:
    logger.exception("Serial startup failed: device=%s", device)
    err = "Cannot open serial interface to a router board."
    if have_uwsgi:
        startup_err = err
    else:
        print()
        print(err)
        print()
        print_software_only_notice()
        sys.exit(-1)
except:
    logger.exception("Unexpected hardware startup failure: device=%s", device)
    err = traceback.format_exc()
    if have_uwsgi:
        startup_err = err
    else:
        print()
        print(err)
        print()
        print_software_only_notice()
        sys.exit(-1)

app.startup_err = startup_err
if app.startup_err:
    logger.info("Bartendro failed to start:")
    logger.error(err)
else:
    try:
        with app.app_context():
            configure_hardware_options(app.options)

            # Verify that drink ID 1 is the "Deleted Drink" placeholder, create if missing
            from bartendro.model.drink import Drink
            from bartendro.model.drink_name import DrinkName
            from bartendro import db
        
            deleted_drink = Drink.query.filter_by(id=1).first()
            if not deleted_drink:
                logging.info("Creating 'Deleted Drink' placeholder at ID 1")
                # Create the drink_name entry
                deleted_name = DrinkName(name="Deleted Drink", sortname="deleted drink")
                db.session.add(deleted_name)
                db.session.flush()
            
                # Use raw SQL to insert with specific ID 1
                from sqlalchemy import text
                db.session.execute(text(
                    "INSERT INTO drink (id, name_id, desc, sugg_size, popular, available) VALUES (1, :name_id, 'This drink has been deleted', 0, 0, 0)"
                ), {'name_id': deleted_name.id})
                db.session.commit()
                logging.info("Created 'Deleted Drink' placeholder at ID 1")
            elif deleted_drink.name.name != "Deleted Drink":
                logger.error("Startup stopped: drink ID 1 must be named 'Deleted Drink', found %r. Fix the database before starting.",
                             deleted_drink.name.name)
                sys.exit(-1)
            else:
                logging.debug("Verified 'Deleted Drink' placeholder exists at ID 1")

            app.mixer = mixer.Mixer(app.driver, app.mc)
            if app.software_only:
                logging.info("Running SOFTWARE ONLY VERSION. No communication between software and hardware chain will happen!")

            logging.info("Bartendro started")
            app.debug = args.debug
            app.version = version
    except Exception:
        logger.exception("Startup failed during database validation or mixer initialization")
        raise

if __name__ == '__main__':
    app.run(host=args.host, port=args.port)
