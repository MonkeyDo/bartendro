# Roadmap

Some improvements we want to make to Bartendro to disentangle it from mayhem's Hippo Oasis and simplify the setup porocess, so it can be used by other people and find a good home.

0. Merge content of /mayhem/bartendro-config into /bartendro/scripts
   * [x] integrate readme.md from there into /docs
   * [x] review the scripts that affect networking - have the RPi setup an AP using available tools on RPI 4
   * [x] review the scripts that point to code running on other machines (this repo /scripts/start_bartendro.sh
   * [ ] create a new install.sh script for newer RaspiOS (Bookworm or above)
   * [ ] modify start_bartendro.sh to use only files within RPI and set to autostart on boot
1. Serve its own wifi access point
   * [ ] Bartendro should not need to connect to internet, so it should create its own AP (Wifi)
   * [ ] install.sh script should automate the selection of raspi-config options necessary for project:
     * [ ] Expand the filesystem (verify this process / requirement)
     * [ ] Set the hostname to bartendro (verify if this is still necessary)
     * [ ] Set the Wifi Country and setup Wifi to a valid network
     * [ ] Advanced: Disable console on serial port, enable serial port
     * [ ] Advanced: Enable I2C
2. Fix annoying bug where drinks will be poured directly from the drinks menu, without waiting for the confirmation screen
   * [ ] Bug found to be called 'Turbo Mode' in the code, it exhibits itself when an admin changes settings in the backend and saves, when the backend refreshes it automatically ticks as active this 'turbo mode'
   * [ ] Monkey to identify flask code that breaks here and propose a patch
3. Better logging within admin UI
   * [ ] write verbose logs to file (rotate logs?)
   * [ ] in admin UI, show logs from file
   * [ ] optional: if admin wishes they can request output of RPI system and kernel logs (makes RPI run `tail -100 /var/log/syslog` or `tail -100 /var/log/kern.log` and displays it in the UI for easy debugging.
4. Create a Setup wizard - current setup is complicated and lots of manual work, requires figuring out combinations on paper and then importing the ingredients and cocktails to bartendro backend
   * [ ] wizard should allow you to easily select ingredients for each pump
   * [ ] then present a list of cocktails that can be served with the available ingredients
   * [ ] allow selecting (tickbox) the cocktails to put on the menu, and which section in the UI they go to
5. Stretch goal: cocktail explorer
   * [ ] need to find an appropriate free API, where you can search by multiple ingredients
   * [ ] on bartendro admin, input your available liquids and fetch a list of cocktails that use them
   * [ ] then import cocktail recipes right into the bartendro database
6. Strech goal: Create new .img release after code has been tested as working on Raspberry Pi 4 (Bullseye, 32 bit)
   * [ ] include: raspi-config already run (setting Wifi country to ES/Spain)
   * [ ] include: all files from the repo
   * [ ] include: information in release page regrading username & passwd + wifi SSID & password of AP
7. Strech goal: Test if Bartendro works for other versions of Raspberry Pi OS
   * [ ] Raspberry Pi OS (Legacy, 32-bit) / Bullseye-armhf-lite (Aug 2021)
   * [ ] Raspberry Pi OS (Legacy, 32-bit) / Bookworm-armhf-lite (June 2023)
   * [ ] Raspberry Pi OS (Legacy, 32-bit) / trixie-armhf-lite (Aug 2025)
   * [ ] Any 64-bit version of Raspberry Pi OS / `¯\_ (ツ)_/¯  will it run?`
8. Investigate user_button.py
    * [x] ref: https://github.com/MonkeyDo/bartendro/commits/master/scripts/user_button.py
    * [x] We discovered it was the code for a custom button that Rob had installed on his personal bot, which allowed for the `bartendro_server.py` to be restarted manually by pressing a button. At somepoint in time Rob replaced this with an LED that indicates whether the liquid levels were low within the backend of the program.
    * [ ] Consider deletion of this code for this repo since it relates to an 'after-market' modification
