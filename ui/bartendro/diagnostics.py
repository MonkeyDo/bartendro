"""Logging context shared by mixer operations and their hardware calls."""
from contextvars import ContextVar
from functools import wraps
import logging
from time import monotonic
from uuid import uuid4


operation_id = ContextVar('operation_id', default='-')
log = logging.getLogger('bartendro')


class OperationFilter(logging.Filter):
    def filter(self, record):
        record.operation_id = operation_id.get()
        return True


class WerkzeugLogFilter(logging.Filter):
    """Lower Werkzeug INFO messages (including HTTP requests) to DEBUG; preserve other levels."""

    def filter(self, record):
        if record.levelno == logging.INFO:
            record.levelno = logging.DEBUG
            record.levelname = 'DEBUG'
        # Werkzeug pins its logger to INFO. Check the remapped level against the
        # root logger, which follows the user's setting, rather than that fixed level.
        return logging.getLogger().isEnabledFor(record.levelno)


def log_operation(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        if operation_id.get() != '-':
            return function(*args, **kwargs)
        token = operation_id.set(uuid4().hex[:12])
        started = monotonic()
        log.debug("Operation started: %s", function.__name__)
        try:
            result = function(*args, **kwargs)
        except Exception:
            log.exception("Operation failed: %s elapsed_ms=%.1f",
                          function.__name__, (monotonic() - started) * 1000)
            raise
        else:
            log.debug("Operation completed: %s elapsed_ms=%.1f",
                      function.__name__, (monotonic() - started) * 1000)
            return result
        finally:
            operation_id.reset(token)
    return wrapped
