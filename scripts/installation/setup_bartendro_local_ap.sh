#!/usr/bin/env bash
#
# Offline Bartendro access point and application setup.
#
# Run this after setup_raspbian_image.sh has installed packages and Python
# dependencies. This script intentionally performs only local configuration:
# it writes hostapd, dnsmasq, nginx, and systemd files from embedded templates,
# enables the services, and points bartendro.local at the local Flask app.

set -euo pipefail

BARTENDRO_CONFIG_FILE="${BARTENDRO_CONFIG_FILE:-/etc/default/bartendro-ap}"
if [ -f "${BARTENDRO_CONFIG_FILE}" ]; then
    . "${BARTENDRO_CONFIG_FILE}"
fi

BARTENDRO_USER="${BARTENDRO_USER:-bartendro}"
BARTENDRO_PASSWORD="${BARTENDRO_PASSWORD:-bartendro}"
BARTENDRO_HOME="${BARTENDRO_HOME:-/home/${BARTENDRO_USER}}"
BARTENDRO_APP_DIR="${BARTENDRO_APP_DIR:-${BARTENDRO_HOME}/bartendro}"
BARTENDRO_UI_DIR="${BARTENDRO_UI_DIR:-${BARTENDRO_APP_DIR}/ui}"
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

log() {
    printf '\n==> %s\n' "$*"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        printf 'Run this script as root, for example: sudo %s\n' "$0" >&2
        exit 1
    fi
}

validate_inputs() {
    if [ ! -d "${BARTENDRO_UI_DIR}" ]; then
        printf 'Bartendro UI directory not found: %s\n' "${BARTENDRO_UI_DIR}" >&2
        exit 1
    fi

    if [ ${#WIFI_PASSWORD} -lt 8 ] || [ ${#WIFI_PASSWORD} -gt 63 ]; then
        printf 'WIFI_PASSWORD must be 8 to 63 characters for WPA2.\n' >&2
        exit 1
    fi

    if [ ! -f "${BARTENDRO_UI_DIR}/bartendro.db" ]; then
        cp "${BARTENDRO_UI_DIR}/bartendro.db.default" "${BARTENDRO_UI_DIR}/bartendro.db"
    fi

    # The Flask app reads/writes bartendro.db and, during database upload,
    # replaces that file and stores the old copy in .db-backups. SQLite may also
    # create journal/WAL sidecar files next to the database, so the UI directory
    # must be writable by the service user. Ownership gives bartendro that write
    # access; 0755 keeps the path traversable for services such as nginx.
    install -d -m 0755 "${BARTENDRO_UI_DIR}/logs" "${BARTENDRO_UI_DIR}/.db-backups"
    chown -R "${BARTENDRO_USER}:${BARTENDRO_USER}" "${BARTENDRO_HOME}"
    chmod 0755 "${BARTENDRO_HOME}" "${BARTENDRO_APP_DIR}" "${BARTENDRO_UI_DIR}"
    chmod 0644 "${BARTENDRO_UI_DIR}/bartendro.db"
    chmod 0755 "${BARTENDRO_UI_DIR}/logs" "${BARTENDRO_UI_DIR}/.db-backups"

    if [ -f "${BARTENDRO_APP_DIR}/scripts/restart_bartendro.sh" ]; then
        install -m 0755 "${BARTENDRO_APP_DIR}/scripts/restart_bartendro.sh" /usr/local/sbin/restart-bartendro
    fi
}

write_runtime_defaults() {
    log "Persisting AP/app defaults for future checks"

    install -d -m 0755 "$(dirname "${BARTENDRO_CONFIG_FILE}")"
    {
        printf 'BARTENDRO_USER=%q\n' "${BARTENDRO_USER}"
        printf 'BARTENDRO_PASSWORD=%q\n' "${BARTENDRO_PASSWORD}"
        printf 'BARTENDRO_HOME=%q\n' "${BARTENDRO_HOME}"
        printf 'BARTENDRO_APP_DIR=%q\n' "${BARTENDRO_APP_DIR}"
        printf 'BARTENDRO_UI_DIR=%q\n' "${BARTENDRO_UI_DIR}"
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

write_wifi_manager_overrides() {
    log "Preventing client Wi-Fi managers from taking ${WIFI_INTERFACE}"

    # Raspberry Pi OS images vary: older images use dhcpcd/wpa_supplicant,
    # newer ones often use NetworkManager. Bartendro needs hostapd to own the
    # wireless interface, so mark wlan0 unmanaged where these managers exist.
    if [ -d /etc/NetworkManager/conf.d ]; then
        cat >/etc/NetworkManager/conf.d/99-bartendro-unmanaged-wlan0.conf <<EOF
# Bartendro AP mode: hostapd owns ${WIFI_INTERFACE}; NetworkManager must not
# start station-mode Wi-Fi on this interface.
[keyfile]
unmanaged-devices=interface-name:${WIFI_INTERFACE}
EOF
    fi

    if [ -f /etc/dhcpcd.conf ] && ! grep -q 'Bartendro AP mode' /etc/dhcpcd.conf; then
        cat >>/etc/dhcpcd.conf <<EOF

# Bartendro AP mode: give ${WIFI_INTERFACE} a stable local address and do not
# launch wpa_supplicant for client Wi-Fi on this interface.
interface ${WIFI_INTERFACE}
static ip_address=${AP_CIDR}
nohook wpa_supplicant
EOF
    fi

    systemctl disable --now "wpa_supplicant@${WIFI_INTERFACE}.service" 2>/dev/null || true
    systemctl disable --now wpa_supplicant.service 2>/dev/null || true
}

write_hostapd_config() {
    log "Writing hostapd access point configuration"

    install -d -m 0755 /etc/hostapd
    cat >/etc/hostapd/hostapd.conf <<EOF
# Bartendro private Wi-Fi access point.
country_code=${WIFI_COUNTRY}
interface=${WIFI_INTERFACE}
driver=nl80211
ctrl_interface=/run/hostapd
ctrl_interface_group=0
ssid=${WIFI_SSID}
hw_mode=g
channel=${WIFI_CHANNEL}
ieee80211n=1
wmm_enabled=1

# WPA2-PSK security. The default passphrase is the same as the bartendro user
# password, matching the appliance-style setup requested for this image.
auth_algs=1
wpa=2
wpa_passphrase=${WIFI_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

    if [ -f /etc/default/hostapd ]; then
        if grep -q '^#\?DAEMON_CONF=' /etc/default/hostapd; then
            sed -i 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
        else
            printf 'DAEMON_CONF="/etc/hostapd/hostapd.conf"\n' >>/etc/default/hostapd
        fi
    else
        printf 'DAEMON_CONF="/etc/hostapd/hostapd.conf"\n' >/etc/default/hostapd
    fi
}

write_dnsmasq_config() {
    log "Writing dnsmasq DHCP and captive DNS configuration"

    install -d -m 0755 /etc/dnsmasq.d
    cat >/etc/dnsmasq.d/bartendro-ap.conf <<EOF
# Serve addresses only on the Bartendro Wi-Fi interface.
interface=${WIFI_INTERFACE}
bind-dynamic

# DHCP lease pool for devices connected to the bartendro access point.
dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},255.255.255.0,15m
dhcp-option=3,${AP_ADDRESS}
dhcp-option=6,${AP_ADDRESS}

# Local names that should reach the appliance.
address=/bartendro/${AP_ADDRESS}
address=/bartendro.local/${AP_ADDRESS}

# Captive DNS behavior: any other hostname also resolves to Bartendro, so users
# connected to the isolated AP land on the local app instead of the internet.
address=/#/${AP_ADDRESS}
local-ttl=3600
domain-needed
bogus-priv
no-resolv
EOF
}

write_interface_service() {
    log "Writing systemd service for the AP interface address"

    cat >/etc/systemd/system/bartendro-wlan0.service <<EOF
[Unit]
Description=Configure ${WIFI_INTERFACE} for the Bartendro access point
Before=hostapd.service dnsmasq.service
Wants=network-pre.target
After=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/ip link set ${WIFI_INTERFACE} down
ExecStart=/usr/sbin/ip addr flush dev ${WIFI_INTERFACE}
ExecStart=/usr/sbin/ip addr add ${AP_CIDR} dev ${WIFI_INTERFACE}
ExecStart=/usr/sbin/ip link set ${WIFI_INTERFACE} up

[Install]
WantedBy=multi-user.target
EOF
}

write_ap_service_ordering() {
    log "Writing service ordering for AP dependencies"

    # hostapd and dnsmasq both need wlan0 to have the static AP address before
    # they start, including when either service is restarted independently.
    install -d -m 0755 /etc/systemd/system/hostapd.service.d
    cat >/etc/systemd/system/hostapd.service.d/10-bartendro-wlan0.conf <<EOF
[Unit]
Requires=bartendro-wlan0.service
After=bartendro-wlan0.service
EOF

    install -d -m 0755 /etc/systemd/system/dnsmasq.service.d
    cat >/etc/systemd/system/dnsmasq.service.d/10-bartendro-wlan0.conf <<EOF
[Unit]
Requires=bartendro-wlan0.service
After=bartendro-wlan0.service
EOF
}

write_bartendro_service() {
    log "Writing Bartendro application service"

    cat >/etc/systemd/system/bartendro.service <<EOF
[Unit]
Description=Bartendro Python web application
After=memcached.service
Requires=memcached.service

[Service]
Type=simple
# The legacy uWSGI setup ran Bartendro as root. Keep root here because the app
# opens serial, I2C, GPIO, and NeoPixel devices during startup.
User=root
WorkingDirectory=${BARTENDRO_UI_DIR}
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=-/run/bartendro-restart.env
ExecStart=${BARTENDRO_UI_DIR}/.venv/bin/python ${BARTENDRO_UI_DIR}/bartendro_server.py --host ${BARTENDRO_HOST} --port ${BARTENDRO_PORT} \$BARTENDRO_SERVER_ARGS
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

write_nginx_config() {
    log "Writing nginx reverse proxy and redirect configuration"

    cat >/etc/nginx/sites-available/bartendro <<EOF
# Bartendro app upstream. The Python service listens only on localhost; nginx is
# the public HTTP entry point for Wi-Fi clients.
upstream bartendro_app {
    server ${BARTENDRO_HOST}:${BARTENDRO_PORT};
}

server {
    listen 80;
    server_name bartendro bartendro.local;

    access_log /var/log/nginx/bartendro-access.log;
    error_log /var/log/nginx/bartendro-error.log notice;

    location / {
        proxy_pass http://bartendro_app;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }
}

server {
    listen 80 default_server;
    server_name _;

    # Unknown HTTP hostnames are redirected to the stable local appliance name.
    # HTTPS captive-portal attempts cannot be intercepted cleanly without a
    # trusted certificate, so this intentionally handles plain HTTP only.
    return 302 http://bartendro.local\$request_uri;
}
EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/bartendro /etc/nginx/sites-enabled/bartendro
    nginx -t
}

write_hosts_file() {
    log "Adding local host aliases"

    if ! grep -qE "^[[:space:]]*${AP_ADDRESS}[[:space:]].*bartendro.local" /etc/hosts; then
        printf '%s bartendro bartendro.local\n' "${AP_ADDRESS}" >>/etc/hosts
    fi

    # .local is commonly resolved with mDNS. Set the hostname and enable Avahi
    # so clients that prefer mDNS can still reach http://bartendro.local/.
    if ! command -v hostnamectl >/dev/null 2>&1 || ! hostnamectl set-hostname bartendro; then
        printf 'bartendro\n' >/etc/hostname
    fi
}

enable_services() {
    log "Enabling services"

    systemctl daemon-reload

    # Restart NetworkManager if it is active so the unmanaged-interface rule is
    # applied before hostapd starts. Ignore absent services for older images.
    if systemctl is-active --quiet NetworkManager.service 2>/dev/null; then
        systemctl restart NetworkManager.service
    fi

    systemctl unmask hostapd || true
    systemctl enable avahi-daemon memcached bartendro-wlan0 hostapd dnsmasq bartendro nginx
    systemctl restart avahi-daemon memcached bartendro-wlan0 hostapd dnsmasq bartendro nginx
}

main() {
    require_root
    validate_inputs
    write_runtime_defaults
    write_wifi_manager_overrides
    write_hostapd_config
    write_dnsmasq_config
    write_interface_service
    write_ap_service_ordering
    write_bartendro_service
    write_nginx_config
    write_hosts_file
    enable_services

    log "Local Bartendro AP setup complete"
    cat <<EOF
Wi-Fi SSID/password: ${WIFI_SSID}/${WIFI_PASSWORD}
App URL:             http://bartendro.local/
AP address:          http://${AP_ADDRESS}/

Useful status commands:
    systemctl status bartendro hostapd dnsmasq nginx avahi-daemon
    journalctl -u bartendro -u hostapd -u dnsmasq -u nginx -u avahi-daemon -f

Verify the finished setup with:
    sudo check-bartendro-setup
EOF
}

main "$@"
