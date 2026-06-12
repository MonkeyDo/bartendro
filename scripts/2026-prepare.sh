# NOTE: new script that only calls online elements from 2026-install.sh and prepares the RPI for the full install.
# Once that script is fully run the user will be asked to reboot the PI into a wifi-hotspot mode (no internet) and run the install.sh to finalise setup (2 steps)

#!/bin/bash

# NEW: automated backups of the files we modify in this and install.sh
sudo cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.backup
sudo cp /etc/iptables/rules.v4 /etc/iptables/rules.v4.backup
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup

# package getting
apt-get update
apt-get install -y --no-install-recommends hostapd isc-dhcp-server iptables-persistent dnsmasq \
    nginx uwsgi uwsgi-plugin-python python-dev python-smbus git-core python-pip python-setuptools python-wheel
apt-get upgrade

# firewall setting
iptables -A FORWARD -i eth0 -o wlan0 -m state --state  RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
iptables -t nat -S
sh -c "iptables-save > /etc/iptables/rules.v4"

# PROPOSAL: removing all make a user called bartendro part of the proces.... have everything point to /home/pi which is the default RPI OS user
# create the bartendro user 
sudo adduser -gecos 'Bartendro' --disabled-password bartendro
sudo adduser bartendro sudo
echo 'bartendro:hackme!' | sudo chpasswd

# git clone bartendro repository
if [ ! -d "/home/bartendro/bartendro" ]; then
    git clone https://github.com/partyrobotics/bartendro.git /home/bartendro/bartendro
    cp /home/bartendro/bartendro/ui/bartendro.db.default /home/bartendro/bartendro/ui/bartendro.db
    chown -R bartendro:bartendro /home/bartendro
fi

# Install the needed python modules
pip install -r /home/bartendro/bartendro/ui/requirements.txt

# PROPOSAL: removing all make a user called bartendro part of the proces.... have everything point to /home/pi which is the default RPI OS user
# change the ownership of everything in the bartendro user
chown -R bartendro:bartendro /home/bartendro

echo "Now reboot, log back in and remove the pi user with:"
echo "   sudo deluser --force --remove-home --remove-all-files pi"
