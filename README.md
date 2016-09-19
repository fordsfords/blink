# blink
C.H.I.P. program to blink status LED and shut down when reset if briefly pressed.

## License

I want there to be NO barriers to using this code, so I am releasing it to the public domain.  But "public domain" does not have an internationally agreed upon definition, so I use CC0:

Copyright 2016 Steven Ford http://geeky-boy.com and licensed
"public domain" style under
[CC0](http://creativecommons.org/publicdomain/zero/1.0/): 
![CC0](https://licensebuttons.net/p/zero/1.0/88x31.png "CC0")

To the extent possible under law, the contributors to this project have
waived all copyright and related or neighboring rights to this work.
In other words, you can use this code for any purpose without any
restrictions.  This work is published from: United States.  The project home
is https://github.com/fordsfords/blink/tree/gh-pages

To contact me, Steve Ford, project owner, you can find my email address
at http://geeky-boy.com.  Can't see it?  Keep looking.


## Introduction

The "[C.H.I.P.](http://getchip.com/)" single-board computer runs Linux.  As a result, it should be shut down gracefully, not abruptly (e.g. by removing power).  But CHIP is often used as an embedded system without any user interface.  In those cases, it can be difficult to know if it has successfully booted, and is difficult to trigger a graceful shutdown.  The "blink" program solves both problems.

* At CHIP boot time, blink can indicate successful boot by blinking an LED (CHIP's status LED and/or an external GPIO output).

* Blink can shut down CHIP gracefully through any of several configurable triggers, including button press, battery charge level, and temperature.

* In addition, blink can enter a warning state based on configurable warning thresholds for battery and temperature.  When in warning state, the LED is blinked faster, and each warning can be configured to trigger a GPIO output.

You can find blink on github.  See:

* User documentation (this README): https://github.com/fordsfords/blink/tree/gh-pages

Note: the "gh-pages" branch is considered to be the current stable release.  The "master" branch is the development cutting edge.


## Quick Start

These instructions assume you are in a shell prompt on CHIP.

1. Prerequisites.  If you plan on blinking CHIP's status LED, and/or monitoring the reset button and/or battery, you will need the "i2c-tools" package, installable like this:

        sudo apt-get install i2c-tools

    If you plan to use GPIO inputs and/or outputs, you will need "gpio_sh" package, installable like this:

        sudo wget -O /usr/local/bin/gpio.sh http://fordsfords.github.io/gpio_sh/gpio.sh

    (See https://github.com/fordsfords/gpio_sh/tree/gh-pages for details of "gpio_sh".)

2. If you have an earlier version of blink running, kill it:

        sudo service blink stop

    If that returns a failure, enter:

        sudo kill `cat /tmp/blink.pid`

3. Get the project files onto CHIP:

        sudo wget -O /usr/local/bin/blink.sh http://fordsfords.github.io/blink/blink.sh
        sudo chmod +x /usr/local/bin/blink.sh
        sudo wget -O /etc/systemd/system/blink.service http://fordsfords.github.io/blink/blink.service
        sudo systemctl enable /etc/systemd/system/blink.service

    If installing blink for the first time, get the configuration file:

        sudo wget -O /usr/local/etc/blink.cfg http://fordsfords.github.io/blink/blink.cfg

    If upgrading blink and have a configuration file, you can skip that step.

4. Now test it:

        sudo service blink start

5. After a few seconds watching the blinking LED, briefly press the reset button and watch CHIP shut down.  Restart CHIP, and when it has completed its reboot, watch the status LED start to blink again.

6. Check logging:

        grep blink /var/log/syslog


## Details

Blink can monitor up to 4 conditions in any combination:
* Short press of reset button.
* A confiured GPIO input reading a configured value (e.g. an external button).
* The AXP209 temperature exceeding a configured threshold.
* The battery charge level dropping below a configured threshold (only applies if CHIP is running only on battery; an external power source will suppress battery monitoring).

While blink is running, it can be configured to blink either CHIP's status LED,
or an external LED connected to a GPIO output (or both).

There are actually two configurable thresholds available for battery and
temperature, a warning threshold and a shutdown threshold.  There is also a
configurable GPIO output that can be associated with the battery and/or the
temperature.  For example, the temperature warning GPIO could turn on a fan,
and the battery warning GPIO could be used to power down an external device to
reduce current consumption.

Note that if blink shuts CHIP down due to low battery, it will not be possible to boot CHIP successfully without connecting to a power supply.  If you try, blink will immediately detect low battey and will shut down before the system is fully booted.  Similarly, if blink shuts CHIP down due to high temperature, you must let CHIP cool before you can boot it.
## Killing Blink

Since blink is a service, you can manually stop it with:

        sudo service blink stop


## Configuring Blink

Edit the file /usr/local/etc/blink.cfg it should look like this:

        # blink.cfg -- version 24-Jul-2016
        # Configuration for /usr/local/bin/blink.sh which is normally
        # installed as a service started at bootup.
        # See https://github.com/fordsfords/blink/tree/gh-pages

        BLINK_STATUS=1       # Blink CHIP's status LED.
        #BLINK_GPIO=XIO_P7    # Blink a GPIO.

        MON_RESET=1          # Monitor reset button for short press.
        #MON_GPIO=XIO_P4      # Shutdown when this GPIO is triggered.
        #MON_GPIO_VALUE=0     # The value read from MON_GPIO that initiates shutdown.

        #MON_BATTERY=7        # When battery percentage is below this, shut down.
        #WARN_BATTERY=9       # When battery percentage is below this, assert warning.
        #WARN_BATTERY_GPIO=XIO_P5  # When battery warning, activate this GPIO.
        #WARN_BATTERY_GPIO_VALUE=0 # Warning value to write to WARN_BATTERY_GPIO.

        #MON_TEMPERATURE=800  # Shutdown temperature in tenths of a degree C. 
        #WARN_TEMPERATURE=750 # Warning temperature in tenths of a degree C. 
        #WARN_TEMPERATURE_GPIO=XIO_P6  # When temperature warning, activate this GPIO.
        #WARN_TEMPERATURE_GPIO_VALUE=0 # Warning value to write to
        #WARN_TEMPERATURE_GPIO.

The hash sign (#) represents a comment.  Most lines are commented, so their functions do not apply.  I.e. the above (default) configuration only blinks CHIP's status LED and only monitors the reset button for short press.  You can enable a function by uncomment its (remove the hash signs).  Or you can comment lines (add the hash) to disable a method.

Do not add any spaces before or after the equals sign.

For example, to skip all blinkign LEDs, and only monitor the battery,
writing "1" to GPIO CSID0 when the battery drops below 10%, and shutting down
when the battery drops below 5%:

        #BLINK_STATUS=1       # Blink CHIP's status LED.
        #BLINK_GPIO=XIO_P7    # Blink a GPIO.

        #MON_RESET=1          # Monitor reset button for short press.
        #MON_GPIO=XIO_P4      # Shutdown when this GPIO is triggered.
        #MON_GPIO_VALUE=0     # The value read from MON_GPIO that initiates shutdown.

        MON_BATTERY=5         # When battery percentage is below this, shut down.
        WARN_BATTERY=10       # When battery percentage is below this, assert warning.
        WARN_BATTERY_GPIO=CSID0   # When battery warning, activate this GPIO.
        WARN_BATTERY_GPIO_VALUE=1 # Warning value to write to WARN_BATTERY_GPIO.

        #MON_TEMPERATURE=800  # Shutdown temperature in tenths of a degree C. 
        #WARN_TEMPERATURE=750 # Warning temperature in tenths of a degree C. 
        #WARN_TEMPERATURE_GPIO=XIO_P6  # When temperature warning, activate this GPIO.
        #WARN_TEMPERATURE_GPIO_VALUE=0 # Warning value to write to
        #WARN_TEMPERATURE_GPIO.

## Random Notes

1. Blink logges informational (and maybe error) messages to /var/log/daemon.log

2. There is an older C version of blink which uses a GPIO line instead of the reset button.  Given that the reset button is much better, I don't anticipate the C program will be of interest except perhaps as a simple example of a C program accessing the GPIO lines.

3. As long as the status LED continues to blink, you know that your CHIP is still running.  But if you are running some useful application, the blinking LED does not necessarily give you a good indication of the overall health of your system.  Basically, blink shows that the OS is still running, but your application may have crashed.

4. There are often ways of automatically monitoring the health of applications.  At a crude level, you can periodically run the "ps" command and at least make sure the process itself is still running.  Even better would be to be able to "poke" the application in some way to produce an expected result (like maybe sending it a signal and writing the application to write a message to a log file).  You could build this capability into blink, and if it detects a failure, change the blink rate of the LED (like to 3 pulses per second).  This still won't tell you *what* is wrong, but at least it narrows things down a bit.

5. The battery charge level is susceptable to "bit bobble", i.e. it can cycle between two values fairly rapidly.  The CHIP temperature measurement can vary randomly within about a .9 degree range.  To avoid rapid cycling of the warning state, blink adds [hysteresis](https://en.wikipedia.org/wiki/Hysteresis) to the warning thresholds.  For example, if CHIP's temperature exceeds the warning threshold, the temperature warning state is entered.  If the temperature then starts to fall, it must fall to 1.1 degrees lower then the warning threshold to exit the warning state.


## Release Notes

* 17-Sep-2016

    Added temperature monitoring, and also added warning levels.
    Re-wrote the code pretty much from scratch.

* 13-Sep-2016

    Fixed a tight loop when battery not being monitored.

* 10-Sep-2016

    Removed writes to blink.log.  Fixed another "unary operator expected" bug.

* 5-Sep-2016

    Changed logging to go to syslog.  Changed PID file to /run/blink.pid  Some
    doc improvements.

* 28-Aug-2016

    Fixed small bug that caused "chip blink.sh[273]: /usr/local/bin/blink.sh:

        line 169: [: -eq: unary operator expected".

* 24-Jul-2016

    Added ability initiate shutdown based on monitoring a GPIO input pin and/or battery charge level.
    Added ability to blink a GPIO output pin.
    Added log file to /var/log.

* 27-Jun-2016

    Changed service type from "forked", which was both misspelled AND the wrong
    choice, to "simple".  Also added spaces after the "-O" of wget to be more
    familliar.

* 26-Jun-2016

    Corrected typo.  Added version ID to blink script.  (Version ID is the
    release date.)

* 30-May-2016

    Checked for short button press properly (masking the correct bit).

* 16-May-2016

    Got rid of sleep 10.  Added "blink.service" to start as system service instead of cron job.  Also re-added the /tmp/blink.pid file.

* 17-Apr-2016

    Created shell script which accesses reset button instead of GPIO line.

* 21-Feb 2016

    Merged in Efreak's ontime/offtime

* 17-Feb-2016

    Added binary executable to package.  Updated quickstart to use it.  Made a few more improvements to documentation.  Also changed the 1 second sleep to 1 million microseconds to make it easier to use a faster blink rate.  Also added /tmp/blink.pid file.

* 24-Jan-2016

    Initial pre-release.
