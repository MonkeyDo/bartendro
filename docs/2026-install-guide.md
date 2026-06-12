## Gude: How to install Bartendro on a new machine

### BEFORE YOU BEGIN

Bartendro requires not just a RPI 4 but many other parts: a custom router board printed by Party Robotics, the dispensers, their individual minirouters, cabling, tubing, etc - the open schematics of these can be found in [the original repo in the /hardware folder.](https://github.com/partyrobotics/bartendro/tree/master/hardware)

This project requires that you build your own bartendro or procure one from a former kickstart backer or client.

In this revival of the code, we will seek to test it on other platforms and OS versions, but at this moment bartendro only works on a RPI 4 running 32-bit RaspiOS based on Buster - please see ROADMAP.md for updates on our testing.

There are currently **two ways** in which a new user can setup a Bartendro bot using this repository: the lazy way (flashing an image onto an SD card) and the nerd way (SSH or connect a monitor to the RPI and setup Bartendro using the command line). We have only tested the Lazy Way and the image linked below is the updated 2026 version, if you wish to flash the original SD card image please download the file in the [2021-05-21 release from Party Robotics.](https://github.com/partyrobotics/bartendro/releases/tag/v-2021-05-21)

### THE LAZY WAY

* get a Raspberry Pi model 4 and an SD card (4GB at least)
* download the 2026 version of the .img file from the [latest releases](https://github.com/MonkeyDo/bartendro/releases) - this image has been bundeled with all the necessary dependencies and requirements for the software.
* flash the image onto the SD card using software such as RPI Imager, Balena Etcher, Rufus or other.
* insert SD card into RPI slot 
* connect the RPI to the the Bartendro control board via the GPIO pins
* connect pumps to the control board using the ethernet cables
* power up the RPI using the correct powersupply (the control board gets power from the RPI)
* if all goes well the LEDs on the pumps should turn on and a new Wifi network called `bartendro` should appear 
* can connect to `bartendro` wifi / the password is `boozemeup`
* After connecting a captive-portal should pop-up on your device, if not use a web-browser and navigate to 10.0.0.10 or bartendro.local
* Note: If there is no wifi network something went wrong with setup, verify the SD card is well seated in the slot on RPI and try again.
* Note: In this release the Wifi Country is set to ES (Spain) within the RPI settings, if you are in a different country you should run `sudo raspi-config` on the RPI to be able to change it to your current region (this affects which bands the wifi uses)
* Fill up your containers and test the pumps are working 
* See 2026-user-guide.md for how to use the UI and calibrate bartendro before serving your first robo-cocktail!
  

### THE NERD WAY

**NOTE: this method has not been verified and uses a script from a personal repo of Rob at [https://github.com/mayhem/bartendro-config](https://github.com/mayhem/bartendro-config)** 

1. Flash
* Download and write the RaspberryPi OS Lite to an SD Card - Bartendro has only been tested as working on the Raspberry Pi OS (Legacy, 32-bit) / Buster-armhf-lite (March 2021) - [Direct download](https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip) 

2. RPI related configuration
* Insert flashed SD card into RPI slot and boot the device
* SSH into the RPI **or** connect a monitor and keyboard to the RPI
* Boot the RPi and then log in as user 'pi' with password 'raspberry'
* From the command line run `sudo raspi-config`
  * Localisation Options: Set the Wifi Country and setup Wifi to a valid network (option L4)
  * System Options: Set the hostname to bartendro (option S3)
  * System Options: Connect to your wifi here if you are not using a Ethernet cable (option S1)
  * Interface Options: Enable SSH (Option P2)
  * Interface Options: Disable console on serial port (first choice: NO), but do enable serial port (second choice: YES) (Option P6)
  * Interface Options: Enable I2C (Option P5)
  * Advanced Options: Expand the filesystem (option A1)
  * navigate to 'Finish' & select YES when asked if raspberry pi should reboot (IMPORTANT)

3. Running prepare.sh scripts
*  TBC

3. Running install,sh scripts
* Once the RPI reboots fully use another device to `ssh pi@bartendro.local` (or use monitor and keyboard attached to the RPI)
* Log in again (pi/raspberry), connect to the RPI to the internet via wifi or the ethernet port, and follow these steps:

```
sudo su -
apt-get update
apt-get install -y git
git clone https://github.com/mayhem/bartendro-config.git
```

* This may take a few minutes to download all the files from github - once completed proceed with:
  
```
cd scripts
chmod +x install.sh
./install.sh
```

* During the package install step, it will ask two questions about firewall files. Answer both with YES. (TBC)
* Once done rebooting, log into the RPi with user `bartendro` and password `hackme!` (TBC)
* As an additional step you can also remove the 'pi' user from sysytem: `sudo deluser --force --remove-home --remove-all-files pi` - note: if you do this step you can now you can no longer log in as `pi`

"In theory that should be it. Your SD card should be ready to rock." - Mayhem
