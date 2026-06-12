#!/usr/bin/env bash
#
# Bartendro setup verification.
#
# Run this on the Raspberry Pi after setup_raspbian_image.sh and
# setup_bartendro_local_ap.sh. It checks the user/source tree, services, AP
# configuration, wlan0 address, DNS behavior, and that http://bartendro.local/
# returns a Bartendro page through nginx.

set -u

BARTENDRO_CONFIG_FILE="${BARTENDRO_CONFIG_FILE:-/etc/default/bartendro-ap}"
if [ -f "${BARTENDRO_CONFIG_FILE}" ]; then
    . "${BARTENDRO_CONFIG_FILE}"
fi

BARTENDRO_USER="${BARTENDRO_USER:-bartendro}"
BARTENDRO_HOME="${BARTENDRO_HOME:-/home/${BARTENDRO_USER}}"
BARTENDRO_APP_DIR="${BARTENDRO_APP_DIR:-${BARTENDRO_HOME}/bartendro}"
BARTENDRO_UI_DIR="${BARTENDRO_UI_DIR:-${BARTENDRO_APP_DIR}/ui}"
BARTENDRO_HOST="${BARTENDRO_HOST:-127.0.0.1}"
BARTENDRO_PORT="${BARTENDRO_PORT:-8080}"

WIFI_INTERFACE="${WIFI_INTERFACE:-wlan0}"
WIFI_SSID="${WIFI_SSID:-bartendro}"
WIFI_COUNTRY="${WIFI_COUNTRY:-ES}"
AP_ADDRESS="${AP_ADDRESS:-10.0.0.1}"
AP_CIDR="${AP_CIDR:-10.0.0.1/24}"
DHCP_RANGE_START="${DHCP_RANGE_START:-10.0.0.100}"
DHCP_RANGE_END="${DHCP_RANGE_END:-10.0.0.250}"

FAILURES=0
WARNINGS=0

pass() {
    printf 'PASS: %s\n' "$*"
}

fail() {
    printf 'FAIL: %s\n' "$*"
    FAILURES=$((FAILURES + 1))
}

warn() {
    printf 'WARN: %s\n' "$*"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    printf 'INFO: %s\n' "$*"
}

have_command() {
    command -v "$1" >/dev/null 2>&1
}

check_file_contains() {
    file="$1"
    pattern="$2"
    description="$3"

    if [ ! -f "${file}" ]; then
        fail "${description}: missing ${file}"
        return
    fi

    if grep -Eq "${pattern}" "${file}"; then
        pass "${description}"
    else
        fail "${description}: ${file} does not match ${pattern}"
    fi
}

check_user_and_files() {
    info "Checking Bartendro user and application files"

    if id "${BARTENDRO_USER}" >/dev/null 2>&1; then
        pass "user ${BARTENDRO_USER} exists"
    else
        fail "user ${BARTENDRO_USER} does not exist"
    fi

    [ -d "${BARTENDRO_UI_DIR}" ] \
        && pass "UI directory exists at ${BARTENDRO_UI_DIR}" \
        || fail "UI directory missing at ${BARTENDRO_UI_DIR}"

    [ -x "${BARTENDRO_UI_DIR}/.venv/bin/python" ] \
        && pass "Python virtual environment exists" \
        || fail "Python virtual environment missing at ${BARTENDRO_UI_DIR}/.venv"

    [ -f "${BARTENDRO_UI_DIR}/bartendro.db" ] \
        && pass "Bartendro database exists" \
        || fail "Bartendro database missing at ${BARTENDRO_UI_DIR}/bartendro.db"

    if [ -r "${BARTENDRO_UI_DIR}/bartendro.db" ] && [ -w "${BARTENDRO_UI_DIR}/bartendro.db" ]; then
        pass "Bartendro database is readable and writable by the checker"
    else
        fail "Bartendro database is not readable/writable by the checker"
    fi

    if [ -w "${BARTENDRO_UI_DIR}/logs" ]; then
        pass "Bartendro log directory is writable by the checker"
    else
        fail "Bartendro log directory is not writable by the checker"
    fi

    [ -x /usr/local/sbin/setup-bartendro-local-ap ] \
        && pass "offline setup script is staged" \
        || warn "offline setup script is not staged at /usr/local/sbin/setup-bartendro-local-ap"

    [ -x /usr/local/sbin/check-bartendro-setup ] \
        && pass "verification script is staged" \
        || warn "verification script is not staged at /usr/local/sbin/check-bartendro-setup"

    if [ -x "${BARTENDRO_UI_DIR}/.venv/bin/python" ]; then
        "${BARTENDRO_UI_DIR}/.venv/bin/python" - <<'PY' >/tmp/bartendro-import-check.out 2>&1
import flask
import flask_login
import flask_sqlalchemy
import memcache
import serial
import sqlalchemy
import wtforms
print("imports ok")
PY
        if [ $? -eq 0 ]; then
            pass "core Python dependencies import successfully"
        else
            fail "core Python dependency import failed; see /tmp/bartendro-import-check.out"
        fi
    fi
}

check_service_enabled_active() {
    service="$1"

    if ! have_command systemctl; then
        warn "systemctl is not available; cannot check ${service}"
        return
    fi

    if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
        pass "${service} is enabled"
    else
        fail "${service} is not enabled"
    fi

    if systemctl is-active --quiet "${service}" 2>/dev/null; then
        pass "${service} is active"
    else
        fail "${service} is not active"
    fi
}

check_services() {
    info "Checking systemd services"

    for service in \
        avahi-daemon.service \
        memcached.service \
        bartendro-wlan0.service \
        hostapd.service \
        dnsmasq.service \
        bartendro.service \
        nginx.service
    do
        check_service_enabled_active "${service}"
    done
}

check_ap_configuration_files() {
    info "Checking access point configuration files"

    check_file_contains /etc/hostapd/hostapd.conf "^interface=${WIFI_INTERFACE}$" "hostapd uses ${WIFI_INTERFACE}"
    check_file_contains /etc/hostapd/hostapd.conf "^ctrl_interface=/run/hostapd$" "hostapd control interface is enabled"
    check_file_contains /etc/hostapd/hostapd.conf "^ssid=${WIFI_SSID}$" "hostapd SSID is ${WIFI_SSID}"
    check_file_contains /etc/hostapd/hostapd.conf "^country_code=${WIFI_COUNTRY}$" "hostapd country is ${WIFI_COUNTRY}"
    check_file_contains /etc/hostapd/hostapd.conf "^wpa=2$" "hostapd WPA2 is enabled"

    check_file_contains /etc/dnsmasq.d/bartendro-ap.conf "^interface=${WIFI_INTERFACE}$" "dnsmasq uses ${WIFI_INTERFACE}"
    check_file_contains /etc/dnsmasq.d/bartendro-ap.conf "^dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},255\\.255\\.255\\.0,15m$" "dnsmasq DHCP range is expected"
    check_file_contains /etc/dnsmasq.d/bartendro-ap.conf "^address=/bartendro\\.local/${AP_ADDRESS}$" "dnsmasq resolves bartendro.local"
    check_file_contains /etc/dnsmasq.d/bartendro-ap.conf "^address=/#/${AP_ADDRESS}$" "dnsmasq captive DNS catch-all is enabled"

    check_file_contains /etc/nginx/sites-enabled/bartendro "server_name bartendro bartendro\\.local;" "nginx serves bartendro.local"
    check_file_contains /etc/nginx/sites-enabled/bartendro "server ${BARTENDRO_HOST}:${BARTENDRO_PORT};" "nginx proxies to the Bartendro app"
    check_file_contains /etc/systemd/system/hostapd.service.d/10-bartendro-wlan0.conf "^Requires=bartendro-wlan0\\.service$" "hostapd requires wlan0 setup"
    check_file_contains /etc/systemd/system/dnsmasq.service.d/10-bartendro-wlan0.conf "^Requires=bartendro-wlan0\\.service$" "dnsmasq requires wlan0 setup"
    check_file_contains /etc/systemd/system/bartendro.service "^User=root$" "Bartendro service runs as root for hardware/file access"
    check_file_contains /etc/systemd/system/bartendro.service "^WorkingDirectory=${BARTENDRO_UI_DIR}$" "Bartendro service working directory is the UI directory"
    check_file_contains /etc/systemd/system/bartendro.service "^ExecStart=${BARTENDRO_UI_DIR}/\\.venv/bin/python ${BARTENDRO_UI_DIR}/bartendro_server\\.py --host ${BARTENDRO_HOST} --port ${BARTENDRO_PORT}$" "Bartendro service uses the venv Python"
}

check_network_state() {
    info "Checking live network state"

    if have_command ip; then
        if ip addr show dev "${WIFI_INTERFACE}" 2>/dev/null | grep -q "inet ${AP_CIDR}"; then
            pass "${WIFI_INTERFACE} has ${AP_CIDR}"
        else
            fail "${WIFI_INTERFACE} does not have ${AP_CIDR}"
            ip addr show dev "${WIFI_INTERFACE}" 2>/dev/null || true
        fi

        if ip link show dev "${WIFI_INTERFACE}" 2>/dev/null | grep -q "state UP"; then
            pass "${WIFI_INTERFACE} link is up"
        else
            fail "${WIFI_INTERFACE} link is not up"
        fi
    else
        warn "ip command is not available; cannot check ${WIFI_INTERFACE}"
    fi

    if have_command hostapd_cli; then
        ssid="$(hostapd_cli -i "${WIFI_INTERFACE}" status 2>/dev/null | awk -F= '/^ssid=/ {print $2; exit}')"
        if [ "${ssid}" = "${WIFI_SSID}" ]; then
            pass "hostapd is broadcasting SSID ${WIFI_SSID}"
        else
            warn "could not confirm hostapd SSID with hostapd_cli"
        fi
    else
        warn "hostapd_cli is not available; service/config checks still ran"
    fi
}

check_ports() {
    info "Checking listening ports"

    if have_command ss; then
        if ss -ltn | awk '{print $4}' | grep -Eq "(^|:)${BARTENDRO_PORT}$"; then
            pass "Bartendro app is listening on TCP ${BARTENDRO_PORT}"
        else
            fail "Bartendro app is not listening on TCP ${BARTENDRO_PORT}"
        fi

        if ss -ltn | awk '{print $4}' | grep -Eq '(^|:)80$'; then
            pass "nginx is listening on TCP 80"
        else
            fail "nginx is not listening on TCP 80"
        fi

        if ss -lun | awk '{print $5}' | grep -Eq '(^|:)53$'; then
            pass "DNS service is listening on UDP 53"
        else
            fail "DNS service is not listening on UDP 53"
        fi
    else
        warn "ss command is not available; cannot check listening ports"
    fi
}

check_name_resolution() {
    info "Checking name resolution"

    if have_command getent; then
        resolved="$(getent hosts bartendro.local | awk '{print $1; exit}')"
        if [ "${resolved}" = "${AP_ADDRESS}" ]; then
            pass "bartendro.local resolves to ${AP_ADDRESS} locally"
        elif [ -n "${resolved}" ]; then
            fail "bartendro.local resolves to ${resolved}, expected ${AP_ADDRESS}"
        else
            fail "bartendro.local does not resolve locally"
        fi
    else
        warn "getent is not available; cannot check local name resolution"
    fi

    if have_command python3; then
        python3 - "${AP_ADDRESS}" <<'PY' >/tmp/bartendro-dns-check.out 2>&1
import random
import socket
import struct
import sys

ap_address = sys.argv[1]

def encode_name(name):
    encoded = b""
    for label in name.rstrip(".").split("."):
        part = label.encode("ascii")
        encoded += bytes([len(part)]) + part
    return encoded + b"\x00"

def query(name):
    txid = random.randrange(0, 65536)
    packet = struct.pack("!HHHHHH", txid, 0x0100, 1, 0, 0, 0)
    packet += encode_name(name)
    packet += struct.pack("!HH", 1, 1)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(5)
    sock.sendto(packet, (ap_address, 53))
    data, _ = sock.recvfrom(512)
    sock.close()

    answer_count = struct.unpack("!H", data[6:8])[0]
    offset = 12
    while data[offset] != 0:
        offset += data[offset] + 1
    offset += 5

    addresses = []
    for _ in range(answer_count):
        if data[offset] & 0xC0 == 0xC0:
            offset += 2
        else:
            while data[offset] != 0:
                offset += data[offset] + 1
            offset += 1

        rtype, rclass, _ttl, rdlength = struct.unpack("!HHIH", data[offset:offset + 10])
        offset += 10
        rdata = data[offset:offset + rdlength]
        offset += rdlength
        if rtype == 1 and rclass == 1 and rdlength == 4:
            addresses.append(socket.inet_ntoa(rdata))
    return addresses

for name in ("bartendro.local", "example.com"):
    addresses = query(name)
    if ap_address not in addresses:
        raise SystemExit(f"{name} resolved to {addresses}, expected {ap_address}")

print("dns checks ok")
PY
        if [ $? -eq 0 ]; then
            pass "dnsmasq resolves bartendro.local and captive DNS names to ${AP_ADDRESS}"
        else
            fail "dnsmasq query check failed; see /tmp/bartendro-dns-check.out"
        fi
    else
        warn "python3 is not available; cannot query dnsmasq directly"
    fi
}

check_http_landing_page() {
    info "Checking Bartendro HTTP page"

    if ! have_command python3; then
        fail "python3 is not available; cannot perform HTTP checks"
        return
    fi

    python3 - "${AP_ADDRESS}" <<'PY' >/tmp/bartendro-http-check.out 2>&1
import http.client
import re
import sys
import urllib.request

ap_address = sys.argv[1]

def validate(status, body, source):
    if status != 200:
        raise SystemExit(f"{source}: expected HTTP 200, got {status}")
    title = re.search(r"<title>\s*([^<]+?)\s*</title>", body, re.IGNORECASE)
    if not title:
        raise SystemExit(f"{source}: no HTML title found")
    if title.group(1) not in ("Bartendro", "Bartendro error"):
        raise SystemExit(f"{source}: unexpected title {title.group(1)!r}")

with urllib.request.urlopen("http://bartendro.local/", timeout=10) as response:
    body = response.read().decode("utf-8", "replace")
    validate(response.status, body, "http://bartendro.local/")

conn = http.client.HTTPConnection(ap_address, 80, timeout=10)
conn.request("GET", "/", headers={"Host": "bartendro.local"})
response = conn.getresponse()
body = response.read().decode("utf-8", "replace")
validate(response.status, body, f"http://{ap_address}/ with Host: bartendro.local")
conn.close()

print("http checks ok")
PY

    if [ $? -eq 0 ]; then
        pass "http://bartendro.local/ returns a Bartendro page"
        pass "http://${AP_ADDRESS}/ with Host bartendro.local returns a Bartendro page"
    else
        fail "HTTP page check failed; see /tmp/bartendro-http-check.out"
    fi
}

print_summary() {
    printf '\nSummary: %d failure(s), %d warning(s)\n' "${FAILURES}" "${WARNINGS}"

    if [ "${FAILURES}" -eq 0 ]; then
        printf 'Bartendro setup verification passed.\n'
        exit 0
    fi

    printf 'Bartendro setup verification failed.\n'
    exit 1
}

main() {
    check_user_and_files
    check_services
    check_ap_configuration_files
    check_network_state
    check_ports
    check_name_resolution
    check_http_landing_page
    print_summary
}

main "$@"
