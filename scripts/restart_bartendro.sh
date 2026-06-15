#!/usr/bin/env bash
#
# Restart the Bartendro Python application.

set -euo pipefail

BARTENDRO_CONFIG_FILE="${BARTENDRO_CONFIG_FILE:-/etc/default/bartendro-ap}"
if [ -f "${BARTENDRO_CONFIG_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${BARTENDRO_CONFIG_FILE}"
fi

BARTENDRO_USER="${BARTENDRO_USER:-bartendro}"
BARTENDRO_HOME="${BARTENDRO_HOME:-/home/${BARTENDRO_USER}}"
BARTENDRO_APP_DIR="${BARTENDRO_APP_DIR:-${BARTENDRO_HOME}/bartendro}"
BARTENDRO_UI_DIR="${BARTENDRO_UI_DIR:-${BARTENDRO_APP_DIR}/ui}"
BARTENDRO_SERVICE="${BARTENDRO_SERVICE:-bartendro.service}"
START_SCRIPT="${START_SCRIPT:-${BARTENDRO_APP_DIR}/scripts/start_bartendro.sh}"

log() {
    printf '%s\n' "$*"
}

restart_systemd_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    if ! systemctl cat "${BARTENDRO_SERVICE}" >/dev/null 2>&1; then
        return 1
    fi

    log "Restarting ${BARTENDRO_SERVICE} with systemctl"
    if [ "$(id -u)" -eq 0 ]; then
        exec systemctl restart "${BARTENDRO_SERVICE}"
    fi

    if command -v sudo >/dev/null 2>&1; then
        exec sudo systemctl restart "${BARTENDRO_SERVICE}"
    fi

    printf 'Need root privileges to restart %s, and sudo is not available.\n' "${BARTENDRO_SERVICE}" >&2
    exit 1
}

restart_legacy_process() {
    log "Restarting legacy bartendro_server.py process"

    if pgrep -f "[b]artendro_server.py" >/dev/null 2>&1; then
        pkill -TERM -f "[b]artendro_server.py" || true

        for _ in 1 2 3 4 5; do
            if ! pgrep -f "[b]artendro_server.py" >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        if pgrep -f "[b]artendro_server.py" >/dev/null 2>&1; then
            pkill -KILL -f "[b]artendro_server.py" || true
        fi
    fi

    if [ -x "${START_SCRIPT}" ]; then
        exec "${START_SCRIPT}"
    fi

    if [ -x "${BARTENDRO_UI_DIR}/.venv/bin/python" ] && [ -f "${BARTENDRO_UI_DIR}/bartendro_server.py" ]; then
        cd "${BARTENDRO_UI_DIR}"
        exec "${BARTENDRO_UI_DIR}/.venv/bin/python" "${BARTENDRO_UI_DIR}/bartendro_server.py"
    fi

    printf 'Cannot find a Bartendro start command. Checked:\n' >&2
    printf '  %s\n' "${START_SCRIPT}" >&2
    printf '  %s/.venv/bin/python %s/bartendro_server.py\n' "${BARTENDRO_UI_DIR}" "${BARTENDRO_UI_DIR}" >&2
    exit 1
}

if restart_systemd_service; then
    exit 0
fi

restart_legacy_process
