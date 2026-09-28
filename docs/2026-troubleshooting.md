## Troubleshooting Guide for Bartendro (2026)

# The code is broken!

### Forgot the password or want to set a new one?  
navigate to the `http://bartendro.local/admin/lost-passwd` webpage when connected to Bartendro Wi-Fi

### Having problems accessing `bartendro.local`?
double check you are connected to the WiFi network created by the Pi, it can be helpful to remove 'auto-connect' from your configuration for other nearby wifi networks to avoid it connecting to those.

### Getting TLS/SSL certificate or secure connection errors?
this is be design, bartendro does not have a signed SSL certificate, if you can not access the app then ensure that the url in your browser starts with `http://` and not `https://`

### Need to edit something manually? 
All the drinks/menu/dispenser settings can be manually edited in the configuration file found within `/ui/bartendro/options.py` of your Pi.
The WiFi network, bartendro username and password and other Pi related configurations are made during the install script's operation - re-run the script to edit these

# The robot is broken!

### Do you want to put carbonated drinks in Bartendro?
Well don't. The pump system does not operate well with bubbles within the system, and the corrosive nature of some of carbonated drinks can break the delicate pumps and tubing. No coca-cola, fanta, pepsi, tonic water, or other carbonated drinks should be used with Bartendro, if you wish to have a Gin and Tonic - have the robot serve the alcoholic part and the user can add tonic to their drink manually afterwards.

### I am going to use hand-pressed juices with my cocktails!
Amazing, we do as well - hand-pressed juice is the best cocktail ingredient - but you MUST strain the juice and remove all pulp or fiber from the juice. The pumps do not like pulp and fiber going through them, to avoid damaging your pumps and robot always strain your juices and if you buy it commercially ensure juices are 'pulp-free'.

### Why can't Bartendro serve me a shaken cocktail?
Because it does not have hands, but you do. The humans are expected to shake, stir or garnish their cocktails after service by the robot - Bartendro shakes for no man.

### Does liquid keep spilling out of the tubes of Bartendro?
Since this system uses peristaltic pumps, there should always be liquid within the tubes going in and out of the pumps, this system does not like air bubbles. If these tubes are draining themselves after serving a cocktail, then there is a seal problem. remove the dispenser and the rotating mechanism.
To fix this unscrew the plastic nut that connects the clear tubing with the pump's internal tubing. Then use a chopstick or other non-sharp object to push the clear tubing through the nut, there needs to be at least a 0.5 cm excess here. Once done, screw the plastic nut back and test again, the liquid should remain in the tubing after serving.
