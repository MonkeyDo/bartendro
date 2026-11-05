import logging
from bartendro import app, db
from bartendro.model.option import Option
from bartendro.model.shot_log import ShotLog
from sqlalchemy.exc import OperationalError

log = logging.getLogger('bartendro')
LOG_LEVELS = ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')

bartendro_options = {
    'log_level': 'INFO',
    'use_liquid_level_sensors': False,
    'must_login_to_dispense': False,
    'login_name': "bartendro",
    'login_passwd': "boozemeup",
    'metric': False,
    'drink_size': 150,
    'taster_size': 30,
    'shot_size': 30,
    'test_dispense_ml': 10,
    'show_strength': True,
    'show_size': True,
    'show_taster': False,
    'strength_steps': 2,
    'use_shotbot_ui': False,
    'show_feeling_lucky': False,
}


class BadConfigOptionsError(Exception):
    pass


class Options(object):
    '''A simple placeholder for options'''

    def add(self, key, value):
        self.__attr__


def setup_options_table():
    '''Check to make sure the options table is present'''

    if not db.engine.dialect.has_table(db.engine.connect(), "option"):
        log.info("Creating options table")
        option = Option()
        option.__table__.create(db.engine)

    # Try and see if we have a legacy config.py kicking around. If so,
    # import the options and save them in the DB
    try:
        import config
    except ImportError:
        config = None

    # Figure out which, if any options are missing from the options table
    options = db.session.query(Option).all()
    opt_dict = {}
    for o in options:
        opt_dict[o.key] = o.value

    # Now populate missing keys from old config or defaults
    for opt in bartendro_options:
        if not opt in opt_dict:
            log.info("option %s is not in DB." % opt)
            try:
                value = getattr(config, opt)
                log.info("Get option from legacy: %s" % value)
            except AttributeError:
                value = bartendro_options[opt]
                log.info("Get option from defaults: %s" % value)

            log.info("Adding option '%s'" % opt)
            o = Option(opt, value)
            db.session.add(o)

    db.session.commit()

    # This should go someplace else, but not right this second
    if not db.engine.dialect.has_table(db.engine.connect(), "shot_log"):
        log.info("Creating shot_log table")
        shot_log = ShotLog()
        shot_log.__table__.create(db.engine)


def load_options(include_hardware=True):
    '''Load options from the db and make them into a nice an accessible modules'''

    setup_options_table()

    options = Options()
    for o in db.session.query(Option).all():
        try:
            if isinstance(bartendro_options[o.key], int):
                value = int(o.value)
            elif isinstance(bartendro_options[o.key], str):
                value = str(o.value)
            elif isinstance(bartendro_options[o.key], boolean):
                value = boolean(o.value)
            else:
                raise BadConfigOptionsError
        except KeyError:
            # Ignore options we don't understand
            pass

        setattr(options, o.key, value)

    if include_hardware:
        configure_hardware_options(options)

    if options.log_level not in LOG_LEVELS:
        log.warning("Invalid logging level %r; using INFO", options.log_level)
        options.log_level = 'INFO'
    root_logger = logging.getLogger()
    root_logger.setLevel(options.log_level)
    for handler in root_logger.handlers:
        handler.setLevel(options.log_level)

    return options


def configure_hardware_options(options):
    options.i_am_shotbot = app.driver.count() == 1
    if options.i_am_shotbot:
        options.use_shotbot_ui = True
