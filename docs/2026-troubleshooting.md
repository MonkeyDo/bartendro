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

### Does liquid keep spilling out of the tubes of Bartendro?
Since this system uses peristaltic pumps, there should always be liquid within the tubes going in and out of the pumps, this system does not like air bubbles.
If these tubes are draining themselves after serving a cocktail, then there is a seal problem. remove the dispenser and the rotating mechanism.
To fix, unscrew the plastic nut that connects the clear tubing with the pump's internal tubing. Then use a chopstick or other non-sharp object to push the clear tubing through the nut, there needs to be at least a 0.5 cm excess here.
Once done, screw the plastic nut back and test again, the liquid should remain in the tubing after serving.
