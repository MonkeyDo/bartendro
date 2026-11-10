## Troubleshooting Guide for Bartendro (2026)

# The code is broken!

### Tracing a failed drink or hardware operation

Use the `[op=...]` field in the application logs to find messages belonging to the
same operation. Enable Debug logging in the options screen for hardware details.
See [Tracing operations in logs](../ui/README.md#tracing-operations-in-logs) for an
example and an explanation of operation IDs.

### Forgot the password or want to set a new one?  
navigate to the `http://bartendro.local/admin/lost-passwd` webpage when connected to Bartendro Wi-Fi

### Having problems accessing `bartendro.local`?
double check you are connected to the WiFi network created by the Pi, it can be helpful to remove 'auto-connect' from your configuration for other nearby wifi networks to avoid it connecting to those.

### Getting TLS/SSL certificate or secure connection errors?
this is be design, bartendro does not have a signed SSL certificate, if you can not access the app then ensure that the URL in your browser starts with `http://` and not `https://`

### Need to edit something manually? 
All the drinks/menu/dispenser settings can be manually edited in the configuration file found within `/ui/bartendro/options.py` of your Pi.
The WiFi network, bartendro username and password and other Pi related configurations are made during the install script's operation - re-run the script to edit these

### Known Bug in 2021 .img release: liquid keeps pouring after cocktail is served.
At times a specific pump decides to keep pouring a liquid after the amount for the cocktail has been already served, leads to very tiff drinks and overflowing cups. No ability to stop the serving in the UI, only solution is to turn it off & on again. Bug is being worked on to be fixed in 2026 release.

### Known Bug in 2026: cocktail pours upon selection from menu without 'pour drink' confirmation
Yes it is known, yes it is annoying. Will be patching in future release. Only work-around is ensuring cup is ready below pumps before user selects drinks. Restarting the bot sometimes clears issue. Restarting with 'I am feeling Lucky' option might resolve the issue. 

### I found a bug!
Excellent. Report the fucker [here](https://github.com/MonkeyDo/bartendro/issues). 


# The robot is broken!

### Does not turn on when given power
Check the Raspberry Pi and all power related connections, including GPIO pin connections of the Pi to the Router Board. If you see only a red light on the Pi when power is provided then it might be that you are not providing enough power to the board for it to start (undervoltage). If you see no lights on the Pi it maybe a hardware fault or issue with the unit. If there are red AND green lights when power is provided then the Pi is actually booting and the issue may be the Router board or the software running on the SD card of the Pi (green light only means the hardware is OK).

### Do you want to put carbonated liquids in Bartendro?
Well don't. The pump system does not operate well with bubbles within the system, and the corrosive nature of some of carbonated drinks can break the delicate pumps and tubing. No coca-cola, fanta, pepsi, tonic water, or other carbonated drinks should be used with Bartendro, if you wish to have a Gin and Tonic - have the robot serve the alcoholic part and the user can add tonic to their drink manually afterwards.

### Do you want to put milk based liquids in Bartendro?
Well you can.... but.... be ready to do a full clean of the tubes after serving the milky cocktail. These liquids (bailey's, irish cream, etc) will permanently stain the clear tubing that is used to serve the pumps, after drying it will look a moldy yellow/beige. Not a good look for the robot, you will need to replace these soiled tubing before the next time you used the robot. We recommend avoiding milk-based liquids and cocktails if possible, or adding the final ingredient by human hand after the robot has served it.

### I am going to use hand-pressed juices with my cocktails!
Amazing, we do as well - hand-pressed juice is the best cocktail ingredient - **but you MUST strain the juice and remove all pulp or fiber from the juice**. The pumps do not like pulp and fiber going through them, to avoid damaging your pumps and robot always strain your juices and if you buy it commercially ensure juices are 'pulp-free'.

### Why can't Bartendro serve me a shaken cocktail?
Because it does not have hands, but you do. The humans are expected to shake, stir or garnish their cocktails after service by the robot - Bartendro shakes for no man.

### Do the tubes from the pump not retain liquids? Does it fail to dispense liquid when pump is turning?
Since this system uses peristaltic pumps, there should always be liquid within the tubes going in and out of the pumps, this system does not like air bubbles. If these tubes are draining themselves after serving a cocktail, then there is a seal problem. To fix this remove the dispenser from the rotating mechanism, unscrew the plastic nut that connects the clear tubing with the pump's internal tubing. Then use a chopstick or other non-sharp object to push the clear tubing through the nut, there needs to be at least a 0.5 cm excess here. Once done, screw the plastic nut back and test again, the liquid should remain in the tubing after serving.
