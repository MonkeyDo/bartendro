import os
import subprocess
import logging

log = logging.getLogger('bartendro')


BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def restart_application():
    try:
        import uwsgi
        uwsgi.reload()
        return True
    except ImportError:
        pass

    script = find_restart_script()
    if not script:
        log.error("Cannot restart application: no executable restart script found")
        return False

    try:
        subprocess.Popen(
            [script],
            close_fds=True,
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except OSError:
        log.exception("Failed to launch restart script: path=%s", script)
        return False


def find_restart_script():
    candidates = [
        os.environ.get("BARTENDRO_RESTART_SCRIPT"),
        "/usr/local/sbin/restart-bartendro",
        os.path.join(BASE_DIR, "scripts", "restart_bartendro.sh"),
    ]

    for candidate in candidates:
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate

    return None
