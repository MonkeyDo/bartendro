#!/usr/bin/env python

import sys
import logging
from time import sleep

log = logging.getLogger('bartendro')

class GPIO(object):

    def __init__(self, pin):
        self.pin = pin

    def setup(self):
        try:
            f = open("/sys/class/gpio/gpio%d/direction" % self.pin, "w")
        except IOError:
            log.exception("GPIO setup failed: pin=%d path=/sys/class/gpio/gpio%d/direction", self.pin, self.pin)
            return False
        f.write("high\n")
        f.close()

    def low(self):
        try:
            f = open("/sys/class/gpio/gpio%d/value" % self.pin, "w")
        except IOError:
            log.exception("GPIO low failed: pin=%d path=/sys/class/gpio/gpio%d/value", self.pin, self.pin)
            return False
        f.write("0\n")
        f.close()
        return True

    def high(self):
        try:
            f = open("/sys/class/gpio/gpio%d/value" % self.pin, "w")
        except IOError:
            log.exception("GPIO high failed: pin=%d path=/sys/class/gpio/gpio%d/value", self.pin, self.pin)
            return False
        f.write("1\n")
        f.close()
        return True
