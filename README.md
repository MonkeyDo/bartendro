Original README contents
============

Programs for the various systems of the Bartendro drink dispensing robot.

Created by [Pierre Michael](https://github.com/pmich) and [Robert Kaye](https://github.com/mayhem) ~ Copyright (c) Party Robotics 2010-2013

All of the source code in this repository is licensed under the GNU Public License 2.0.
The hardware schematic and layouts are licensed using the Creative Commons 
Attribution-ShareAlike 3.0 Unported license.

The source tree is laid out as follows:

* firmware -- source code (C) for the dispenser and router boards
* scripts  -- scripts to make running the bartendro software easier
* ui       -- web interface for the bot, written in python.

Fork README contents
============





Requirements
==================================
Bartendro requires not just a RPI 4 but many other parts: a custom router board printed by Party Robotics, the dispensers, their individual minirouters, cabling, tubing, etc - the open schematics for these can be found in the [original repository in the /hardware folder.](https://github.com/partyrobotics/bartendro)

This project requires that you build your own bartendro or procure one from a former kickstart backer or client. Without it the code will only run in Debug mode.


Code has been tested as working on
==================================
* [x] Raspberry Pi Os (Legacy, 32-bit) / Buster-armhf-lite (June 2019) / Note: only by using SD card image produced in 2021, Buster no longer supported by Raspbian
* [x] Raspberry Pi OS (Legacy, 32-bit) / Bullseye-armhf-lite (Aug 2021)
* [ ] Raspberry Pi OS (Legacy, 32-bit) / Bookworm-armhf-lite (June 2023)
* [ ] Raspberry Pi OS (Legacy, 32-bit) / trixie-armhf-lite (Aug 2025)
* [ ] Test any arm64-lite version of Raspberry Pi OS / `¯\_ (ツ)_/¯  will it run?`
| here is a link to the [official distro image archive for Raspiberry Pi OS](https://downloads.raspberrypi.com/raspios_lite_armhf/images/)

Releases
==================================
- 2021: .img to be flashed onto an SD card (Working on RPI 3 and 4, based on RaspiOS Bullseye 32-bit): [https://github.com/partyrobotics/bartendro/releases/tag/v-2021-05-21](https://github.com/partyrobotics/bartendro/releases/tag/v-2021-05-21)
- 2026: A snapshot of Bartendro as it was running in 2021 with python 2, before we merge in some improvements that were added at a later date. Removes "turbo mode" and "sobriety check" features that we are not going to use.: [https://github.com/MonkeyDo/bartendro/releases/tag/2021-python2](https://github.com/MonkeyDo/bartendro/releases/tag/2021-python2) 
- 2026: 



Getting started
==================================

- Read the history of Bartendro: [https://github.com/MonkeyDo/bartendro/blob/master/docs/history.md](https://github.com/MonkeyDo/bartendro/blob/master/docs/history.md)
- Read our 'start here' guide: [https://github.com/MonkeyDo/bartendro/blob/master/docs/2026-start-here.md](https://github.com/MonkeyDo/bartendro/blob/master/docs/2026-start-here.md)
- Read the updated docs: [https://github.com/MonkeyDo/bartendro/tree/master/docs](https://github.com/MonkeyDo/bartendro/tree/master/docs)
- Read the install docs: [https://github.com/MonkeyDo/bartendro/blob/master/docs/2026-install-guide.md](https://github.com/MonkeyDo/bartendro/blob/master/docs/2026-install-guide.md)
- Get hold of or build your own Bartendro (see Requirements above)
- flash one of the Releases listed above onto a SD card with at least 4GB of memory
- Follow the full user guide once you have the hardware setup and working: [https://github.com/MonkeyDo/bartendro/blob/master/docs/2026-user-guide.md](https://github.com/MonkeyDo/bartendro/blob/master/docs/2026-user-guide.md)


Links to relevant code repositories
============

1. Archived bartendro code that can be found in [https://github.com/partyrobotics/bartendro](https://github.com/partyrobotics/bartendro):
* hardware -- schematics and layouts for the dispenser and router hardware boards
* tsb      -- legacy code from our old skool drink bot prototyp Tequila Sunrise Bot
2. An open sourced metal frame for holding 3 pumps and all the boards made by Wyolum: [https://github.com/wyolum/bartendro_frame](https://github.com/wyolum/bartendro_frame)
3. Rob's personal repos with additional configuration scripts (outdated): [https://github.com/mayhem/bartendro-config](https://github.com/mayhem/bartendro-config
)
4. Rob's collection of BASH scripts to deploy bartendro: [https://github.com/mayhem/bartendro-deploy](https://github.com/mayhem/bartendro-deploy)
5. Ansible Cookbooks from 2013: [https://github.com/mayhem/bartendro-chef-cookbooks](https://github.com/mayhem/bartendro-chef-cookbooks)

