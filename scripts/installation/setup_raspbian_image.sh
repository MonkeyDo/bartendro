#!/usr/bin/env bash
#
# Online Bartendro Raspberry Pi OS setup.
#
# Run this script first on a fresh Raspberry Pi OS/Raspbian image while the Pi
# still has internet access. It installs every apt and pip dependency needed by
# Bartendro, creates the bartendro login, copies or fetches the application
# source, and stages the offline AP/app configuration script.
#
# After this script completes successfully, setup_bartendro_local_ap.sh should
# be able to run without internet access.

set -euo pipefail

BARTENDRO_USER="${BARTENDRO_USER:-bartendro}"
BARTENDRO_PASSWORD="${BARTENDRO_PASSWORD:-bartendro}"
BARTENDRO_HOME="${BARTENDRO_HOME:-/home/${BARTENDRO_USER}}"
BARTENDRO_APP_DIR="${BARTENDRO_APP_DIR:-${BARTENDRO_HOME}/bartendro}"
BARTENDRO_REPO_URL="${BARTENDRO_REPO_URL:-https://github.com/MonkeyDo/bartendro.git}"
BARTENDRO_CONFIG_FILE="${BARTENDRO_CONFIG_FILE:-/etc/default/bartendro-ap}"
BARTENDRO_HOST="${BARTENDRO_HOST:-127.0.0.1}"
BARTENDRO_PORT="${BARTENDRO_PORT:-8080}"

WIFI_INTERFACE="${WIFI_INTERFACE:-wlan0}"
WIFI_SSID="${WIFI_SSID:-bartendro}"
WIFI_PASSWORD="${WIFI_PASSWORD:-${BARTENDRO_PASSWORD}}"
WIFI_COUNTRY="${WIFI_COUNTRY:-ES}"
WIFI_CHANNEL="${WIFI_CHANNEL:-6}"
AP_ADDRESS="${AP_ADDRESS:-10.0.0.1}"
AP_CIDR="${AP_CIDR:-10.0.0.1/24}"
DHCP_RANGE_START="${DHCP_RANGE_START:-10.0.0.100}"
DHCP_RANGE_END="${DHCP_RANGE_END:-10.0.0.250}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SOURCE_DIR="${SCRIPT_DIR}/bartendro"
LOCAL_AP_SCRIPT="${SCRIPT_DIR}/setup_bartendro_local_ap.sh"
LOCAL_CHECK_SCRIPT="${SCRIPT_DIR}/check_bartendro_setup.sh"
START_AT_STEP="${START_AT_STEP:-}"
ONLY_STEP="${ONLY_STEP:-}"
FORCE_WIZARD=0

log() {
    printf '\n==> %s\n' "$*"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        printf 'Run this script as root, for example: sudo %s\n' "$0" >&2
        exit 1
    fi
}

usage() {
    cat <<EOF
Usage: sudo $0 [options]

Options:
  --reconfigure          Run the setup wizard even if ${BARTENDRO_CONFIG_FILE} exists.
  --start-at STEP        Start at STEP and continue through the remaining steps.
  --only STEP            Run only STEP.
  --help                Show this help.

Steps:
  wizard
  packages
  user
  source
  python
  defaults
  hardware
  stage

Examples:
  sudo $0 --reconfigure
  sudo $0 --start-at python
  sudo $0 --only stage
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --reconfigure)
                FORCE_WIZARD=1
                ;;
            --start-at)
                shift
                if [ "$#" -eq 0 ]; then
                    printf 'Missing value for --start-at\n' >&2
                    exit 1
                fi
                START_AT_STEP="$1"
                ;;
            --only)
                shift
                if [ "$#" -eq 0 ]; then
                    printf 'Missing value for --only\n' >&2
                    exit 1
                fi
                ONLY_STEP="$1"
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                printf 'Unknown option: %s\n\n' "$1" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done
}

is_valid_step() {
    case "$1" in
        wizard|packages|user|source|python|defaults|hardware|stage)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

should_run_step() {
    step="$1"

    if [ -n "${ONLY_STEP}" ]; then
        [ "${step}" = "${ONLY_STEP}" ]
        return
    fi

    if [ -z "${START_AT_STEP}" ]; then
        return 0
    fi

    case "${START_AT_STEP}:${step}" in
        wizard:*) return 0 ;;
        packages:wizard) return 1 ;;
        packages:*) return 0 ;;
        user:wizard|user:packages) return 1 ;;
        user:*) return 0 ;;
        source:wizard|source:packages|source:user) return 1 ;;
        source:*) return 0 ;;
        python:wizard|python:packages|python:user|python:source) return 1 ;;
        python:*) return 0 ;;
        defaults:wizard|defaults:packages|defaults:user|defaults:source|defaults:python) return 1 ;;
        defaults:*) return 0 ;;
        hardware:wizard|hardware:packages|hardware:user|hardware:source|hardware:python|hardware:defaults) return 1 ;;
        hardware:*) return 0 ;;
        stage:stage) return 0 ;;
        stage:*) return 1 ;;
    esac
}

validate_args() {
    if [ -n "${START_AT_STEP}" ] && ! is_valid_step "${START_AT_STEP}"; then
        printf 'Invalid --start-at step: %s\n\n' "${START_AT_STEP}" >&2
        usage >&2
        exit 1
    fi
    if [ -n "${ONLY_STEP}" ] && ! is_valid_step "${ONLY_STEP}"; then
        printf 'Invalid --only step: %s\n\n' "${ONLY_STEP}" >&2
        usage >&2
        exit 1
    fi
    if [ -n "${START_AT_STEP}" ] && [ -n "${ONLY_STEP}" ]; then
        printf 'Use --start-at or --only, not both.\n\n' >&2
        usage >&2
        exit 1
    fi
}

prompt_default() {
    prompt="$1"
    default="$2"
    answer=""

    if [ -t 0 ] && [ -w /dev/tty ]; then
        printf '%s [%s]: ' "${prompt}" "${default}" >/dev/tty
        IFS= read -r answer </dev/tty
    else
        printf '%s [%s]: ' "${prompt}" "${default}" >&2
        IFS= read -r answer
    fi

    if [ -z "${answer}" ]; then
        printf '%s' "${default}"
    else
        printf '%s' "${answer}"
    fi
}

valid_linux_user() {
    # Match Debian adduser's normal-system-user form closely enough to catch
    # empty values and accidental captured prompt text before adduser does.
    printf '%s' "$1" | grep -Eq '^[a-z][-a-z0-9_]*[$]?$'
}

validate_config_values() {
    if ! valid_linux_user "${BARTENDRO_USER}"; then
        printf 'Invalid BARTENDRO_USER value: %s\n' "${BARTENDRO_USER}" >&2
        return 1
    fi
    if [ -z "${BARTENDRO_PASSWORD}" ]; then
        printf 'BARTENDRO_PASSWORD must not be empty.\n' >&2
        return 1
    fi
    if [ ${#WIFI_PASSWORD} -lt 8 ] || [ ${#WIFI_PASSWORD} -gt 63 ]; then
        printf 'WIFI_PASSWORD must be 8 to 63 characters for WPA2.\n' >&2
        return 1
    fi
    return 0
}

run_setup_wizard() {
    if [ -f "${BARTENDRO_CONFIG_FILE}" ] && [ "${FORCE_WIZARD}" -eq 0 ]; then
        log "Using existing setup defaults from ${BARTENDRO_CONFIG_FILE}"
        # shellcheck disable=SC1090
        . "${BARTENDRO_CONFIG_FILE}"
        if ! validate_config_values; then
            if [ -t 0 ]; then
                printf 'Existing setup defaults are invalid; rerunning the wizard.\n' >&2
                if ! valid_linux_user "${BARTENDRO_USER}"; then
                    BARTENDRO_USER="bartendro"
                    BARTENDRO_HOME="/home/${BARTENDRO_USER}"
                    BARTENDRO_APP_DIR="${BARTENDRO_HOME}/bartendro"
                fi
            else
                printf 'Fix %s or rerun interactively with --reconfigure.\n' "${BARTENDRO_CONFIG_FILE}" >&2
                exit 1
            fi
        else
            return
        fi
    elif [ -f "${BARTENDRO_CONFIG_FILE}" ]; then
        log "Ignoring existing setup defaults because --reconfigure was requested"
        # shellcheck disable=SC1090
        . "${BARTENDRO_CONFIG_FILE}"
    fi

    if [ ! -t 0 ]; then
        log "No valid setup defaults and stdin is not interactive; using environment/default values"
        validate_config_values
        write_setup_defaults
        return
    fi

    while true; do
        log "Bartendro setup wizard"
        printf 'Press Enter to accept the value shown in brackets.\n\n'

        BARTENDRO_USER="$(prompt_default 'Linux user name' "${BARTENDRO_USER}")"
        BARTENDRO_PASSWORD="$(prompt_default 'Linux user password' "${BARTENDRO_PASSWORD}")"
        BARTENDRO_HOME="$(prompt_default 'Linux user home' "/home/${BARTENDRO_USER}")"
        BARTENDRO_APP_DIR="$(prompt_default 'Bartendro app directory' "${BARTENDRO_HOME}/bartendro")"
        BARTENDRO_REPO_URL="$(prompt_default 'Fallback Bartendro git repository' "${BARTENDRO_REPO_URL}")"
        BARTENDRO_HOST="$(prompt_default 'Bartendro app bind host' "${BARTENDRO_HOST}")"
        BARTENDRO_PORT="$(prompt_default 'Bartendro app port' "${BARTENDRO_PORT}")"

        WIFI_INTERFACE="$(prompt_default 'Wi-Fi interface' "${WIFI_INTERFACE}")"
        WIFI_SSID="$(prompt_default 'Wi-Fi access point SSID' "${WIFI_SSID}")"
        WIFI_PASSWORD="$(prompt_default 'Wi-Fi access point password' "${WIFI_PASSWORD}")"
        WIFI_COUNTRY="$(prompt_default 'Wi-Fi country code' "${WIFI_COUNTRY}")"
        WIFI_CHANNEL="$(prompt_default 'Wi-Fi channel' "${WIFI_CHANNEL}")"
        AP_ADDRESS="$(prompt_default 'Access point IP address' "${AP_ADDRESS}")"
        AP_CIDR="$(prompt_default 'Access point CIDR address' "${AP_CIDR}")"
        DHCP_RANGE_START="$(prompt_default 'DHCP range start' "${DHCP_RANGE_START}")"
        DHCP_RANGE_END="$(prompt_default 'DHCP range end' "${DHCP_RANGE_END}")"

        if validate_config_values; then
            write_setup_defaults
            log "Saved setup defaults to ${BARTENDRO_CONFIG_FILE}"
            break
        fi

        printf '\nPlease correct the values above.\n' >&2
    done
}

load_setup_defaults_for_resume() {
    if should_run_step wizard; then
        return
    fi

    if [ -f "${BARTENDRO_CONFIG_FILE}" ]; then
        log "Loading setup defaults from ${BARTENDRO_CONFIG_FILE}"
        # shellcheck disable=SC1090
        . "${BARTENDRO_CONFIG_FILE}"
        validate_config_values
    else
        log "No setup defaults found at ${BARTENDRO_CONFIG_FILE}; using environment/default values"
        validate_config_values
    fi
}

run_step() {
    step="$1"
    shift

    if should_run_step "${step}"; then
        "$@"
    else
        log "Skipping step: ${step}"
        return
    fi
}

ensure_user() {
    log "Creating/updating the ${BARTENDRO_USER} user"

    validate_config_values

    if ! id "${BARTENDRO_USER}" >/dev/null 2>&1; then
        # --disabled-password avoids an interactive prompt; chpasswd sets the
        # real password immediately below.
        adduser --gecos 'Bartendro' --disabled-password "${BARTENDRO_USER}"
    fi

    printf '%s:%s\n' "${BARTENDRO_USER}" "${BARTENDRO_PASSWORD}" | chpasswd

    # The original bartendro-config installer gave passwordless sudo to the
    # sudo group. Keep that behavior, but scope it to the Bartendro user.
    for group in sudo dialout video gpio i2c spi; do
        if getent group "${group}" >/dev/null; then
            usermod -aG "${group}" "${BARTENDRO_USER}"
        fi
    done

    install -d -m 0750 /etc/sudoers.d
    cat >/etc/sudoers.d/90-bartendro <<EOF
# Bartendro is an appliance image. The web UI and maintenance scripts expect
# local administrative access without prompting for a password.
${BARTENDRO_USER} ALL=(ALL:ALL) NOPASSWD:ALL
EOF
    chmod 0440 /etc/sudoers.d/90-bartendro
    visudo -cf /etc/sudoers.d/90-bartendro >/dev/null
}

install_system_packages() {
    log "Installing system packages"

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        avahi-daemon \
        build-essential \
        ca-certificates \
        dnsmasq \
        git \
        hostapd \
        i2c-tools \
        iproute2 \
        memcached \
        nginx \
        pkg-config \
        python3-dev \
        python3-pip \
        python3-rpi.gpio \
        python3-smbus \
        python3-venv \
        sqlite3 \
        sudo

    # These services are configured by setup_bartendro_local_ap.sh. Keep them
    # stopped for now so this online provisioning step does not take over Wi-Fi.
    systemctl unmask hostapd || true
    systemctl disable --now hostapd dnsmasq nginx || true
    systemctl enable avahi-daemon memcached
}

install_source_tree() {
    log "Installing Bartendro source in ${BARTENDRO_APP_DIR}"

    install -d -m 0755 "${BARTENDRO_HOME}"

    if [ -d "${BARTENDRO_APP_DIR}/ui" ]; then
        printf 'Bartendro source already exists at %s; leaving it in place.\n' "${BARTENDRO_APP_DIR}"
    elif [ -d "${LOCAL_SOURCE_DIR}/ui" ]; then
        # Prefer the checked-out source sitting next to this script. This keeps
        # local changes and avoids a network clone when the repository is
        # already present on the image.
        cp -a "${LOCAL_SOURCE_DIR}" "${BARTENDRO_APP_DIR}"
    else
        # Fallback for running this script standalone on a connected Pi.
        git clone "${BARTENDRO_REPO_URL}" "${BARTENDRO_APP_DIR}"
    fi

    if [ ! -f "${BARTENDRO_APP_DIR}/ui/bartendro.db" ]; then
        cp "${BARTENDRO_APP_DIR}/ui/bartendro.db.default" "${BARTENDRO_APP_DIR}/ui/bartendro.db"
    fi

    install -d -m 0755 "${BARTENDRO_APP_DIR}/ui/logs"
    chown -R "${BARTENDRO_USER}:${BARTENDRO_USER}" "${BARTENDRO_HOME}"
}

install_python_environment() {
    log "Installing Python dependencies into a project virtual environment"

    python3 -m venv --system-site-packages "${BARTENDRO_APP_DIR}/ui/.venv"
    "${BARTENDRO_APP_DIR}/ui/.venv/bin/python" -m pip install --upgrade pip setuptools wheel
    "${BARTENDRO_APP_DIR}/ui/.venv/bin/python" -m pip install -r "${BARTENDRO_APP_DIR}/ui/requirements.txt"

    chown -R "${BARTENDRO_USER}:${BARTENDRO_USER}" "${BARTENDRO_APP_DIR}/ui/.venv"
}

write_setup_defaults() {
    log "Writing setup defaults for the offline AP script"

    # The second setup step may run after reboot without the environment used
    # for this online step. Persist the appliance defaults so the login password
    # and Wi-Fi password stay in sync.
    install -d -m 0755 "$(dirname "${BARTENDRO_CONFIG_FILE}")"
    {
        printf 'BARTENDRO_USER=%q\n' "${BARTENDRO_USER}"
        printf 'BARTENDRO_PASSWORD=%q\n' "${BARTENDRO_PASSWORD}"
        printf 'BARTENDRO_HOME=%q\n' "${BARTENDRO_HOME}"
        printf 'BARTENDRO_APP_DIR=%q\n' "${BARTENDRO_APP_DIR}"
        printf 'BARTENDRO_REPO_URL=%q\n' "${BARTENDRO_REPO_URL}"
        printf 'BARTENDRO_HOST=%q\n' "${BARTENDRO_HOST}"
        printf 'BARTENDRO_PORT=%q\n' "${BARTENDRO_PORT}"
        printf 'WIFI_INTERFACE=%q\n' "${WIFI_INTERFACE}"
        printf 'WIFI_SSID=%q\n' "${WIFI_SSID}"
        printf 'WIFI_PASSWORD=%q\n' "${WIFI_PASSWORD}"
        printf 'WIFI_COUNTRY=%q\n' "${WIFI_COUNTRY}"
        printf 'WIFI_CHANNEL=%q\n' "${WIFI_CHANNEL}"
        printf 'AP_ADDRESS=%q\n' "${AP_ADDRESS}"
        printf 'AP_CIDR=%q\n' "${AP_CIDR}"
        printf 'DHCP_RANGE_START=%q\n' "${DHCP_RANGE_START}"
        printf 'DHCP_RANGE_END=%q\n' "${DHCP_RANGE_END}"
    } >"${BARTENDRO_CONFIG_FILE}"
    chmod 0600 "${BARTENDRO_CONFIG_FILE}"
}

enable_pi_hardware_interfaces() {
    log "Enabling Raspberry Pi hardware interfaces used by Bartendro"

    # Bartendro talks to the router board over serial and selects dispensers via
    # I2C. raspi-config is present on normal Raspberry Pi OS images; skip this
    # step on non-Pi hosts or stripped-down images.
    if command -v raspi-config >/dev/null 2>&1; then
        raspi-config nonint do_i2c 0 || true
        raspi-config nonint do_serial_hw 0 || true
        raspi-config nonint do_serial_cons 1 || true
    fi

    printf 'i2c-dev\n' >/etc/modules-load.d/bartendro-i2c.conf
}

stage_offline_script() {
    log "Staging the offline AP/app configuration and verification scripts"

    if [ ! -f "${LOCAL_AP_SCRIPT}" ]; then
        printf 'Missing %s; keep setup_bartendro_local_ap.sh next to this script.\n' "${LOCAL_AP_SCRIPT}" >&2
        exit 1
    fi
    if [ ! -f "${LOCAL_CHECK_SCRIPT}" ]; then
        printf 'Missing %s; keep check_bartendro_setup.sh next to this script.\n' "${LOCAL_CHECK_SCRIPT}" >&2
        exit 1
    fi

    install -m 0755 "${LOCAL_AP_SCRIPT}" /usr/local/sbin/setup-bartendro-local-ap
    install -m 0755 "${LOCAL_CHECK_SCRIPT}" /usr/local/sbin/check-bartendro-setup
}

main() {
    parse_args "$@"
    validate_args
    require_root
    load_setup_defaults_for_resume
    run_step wizard run_setup_wizard
    run_step packages install_system_packages
    run_step user ensure_user
    run_step source install_source_tree
    run_step python install_python_environment
    run_step defaults write_setup_defaults
    run_step hardware enable_pi_hardware_interfaces
    run_step stage stage_offline_script

    log "Online provisioning complete"
    cat <<EOF
Installed Bartendro at: ${BARTENDRO_APP_DIR}
Login user/password:    ${BARTENDRO_USER}/${BARTENDRO_PASSWORD}

Next step, which does not require internet:
    sudo /usr/local/sbin/setup-bartendro-local-ap

Verify the finished setup with:
    sudo /usr/local/sbin/check-bartendro-setup

The setup script will switch wlan0 into the Bartendro access point and expose
the app at http://bartendro.local/.
EOF
}

main "$@"
