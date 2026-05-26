## Gude: How to install Bartendro on a new machine

There are currently **two ways** in which a new user can setup a Bartendro bot using this repository: the lazy way (flashing an image onto an SD card) and the nerd way (SSH or connect a monitor to the RPI and setup Bartendro using the command line)

### THE LAZY WAY

* get a RPI 4 and an SD card (4GB at least)
* download the .img file from the [latest releases](https://github.com/MonkeyDo/bartendro/releases)
* flash the image onto the SD card using software such as Balena Etcher or Rufus
* insert SD card into RPI slot and connect to the Bartendro controll board / interface
* power up the RPI and if all goes well a new Wifi network called `bartendro` should appear that you can connect to
* After connecting a captive-portal should pop-up on your device, if not navigate to 10.0.0.10 using a web-browser
* Note: If there is no wifi network something went wrong with setup, try again and verify the SD card is well seated in the slot on RP
* Note: In this release the Wifi Country is set to ES (Spain), if you are in a different country you should run `sudo raspi-config` on the RPI to be able to change it to your current region (affects which bands the wifi uses)
* 

### THE NERD WAY

0. Preparations
*

1. Flash
* Download and write the RaspberryPi OS Lite to an SD Card - Bartendro has been tested on the following releases:
  * Raspberry Pi OS (Legacy, 32-bit) / Buster-armhf-lite (March 2021) - [Direct download](https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip) 
  * **TBC:** Raspberry Pi OS (Legacy, 32-bit) / Bullseye-armhf-lite (Aug 2021)
  * **TBC:** Raspberry Pi OS (Legacy, 32-bit) / Bookworm-armhf-lite (June 2023)
  * **TBC:** Raspberry Pi OS (Legacy, 32-bit) / trixie-armhf-lite (Aug 2025)
  * **TBC:** Any 64-bit version of Raspberry Pi OS / `¯\_ (ツ)_/¯  will it run?`


2. RPI related configuration
* Insert flashed SD card into RPI slot and boot the device
* SSH into the RPI **or** connect a monitor and keyboard to the RPI
* Boot the RPi and then log in as user 'pi' with password 'raspberry'
* From the command line run `sudo raspi-config`
  * Expand the filesystem
  * Set the hostname to bartendro
  * Set the Wifi Country and setup Wifi to a valid network
  * Advanced: Disable console on serial port, enable serial port
  * Advanced: Enable I2C
* IMPORTANT: reboot the RPI right after the raspi-config command `sudo reboot`

3. Running install scripts
* Once the RPI reboots fully use another device to `ssh pi@bartendro.local` (or use monitor and keyboard attached to the RPI)
* Log in again (pi/raspberry), connect to the RPI to the internet via wifi or the ethernet port, and follow these steps:

```
sudo su -
apt-get update
apt-get install -y git
git clone https://github.com/MonkeyDo/bartendro.git
```

* This may take a few minutes to download all the files from github - once completed proceed with:
  
```
cd scripts
chmod +x install.sh
./install.sh
```

* During the package install step, it will ask two questions about firewall files. Answer both with YES. (TBC)
* Once done rebooting, log into the RPi with user 'bartendro' and password 'hackme!' (TBC)
* As an additional step you can also remove the 'pi' user from sysytem by running: `sudo deluser --force --remove-home --remove-all-files pi` - if you do this step you can now you can no longer log in with the standard bartendro user with password "hackme!"



"In theory that should be it. Your SD card should be ready to rock." - Mayhem
