# blink
CHIP program to blink status LED and shut down when XIO-P7 is grounded.

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

The [CHIP](http://getchip.com/) single-board computer runs Linux.  As a result, it should be shut down gracefully, not abruptly by removing power.  But CHIP is often used as an embedded system without any user interface.  In those cases, it can be difficult to know if it has successfully booted, and is difficult to trigger a graceful shutdown.  This program solves both problems.

* When started by root's crontab at boot time, the blinking status LED indicates a successful boot.  Its continuing blinking indicates that CHIP hasn't crashed.

* When the XIO-P7 input is grounded, the blink program will initiate a graceful shutdown.

You can find blink on github.  See:

* User documentation (this README): https://github.com/fordsfords/blink/tree/gh-pages

Note: the "gh-pages" branch is considered to be the current stable release.  The "master" branch is the development cutting edge.

## Quick Start

These instructions assume you are in a shell prompt on CHIP.

1. Get the executable file onto CHIP:

        sudo wget -O/usr/local/bin/blink http://fordsfords.github.io/blink/blink
        sudo chmod +x /usr/local/bin/blink
If you are already running blink and are just refreshing your version, the wget might complain "/usr/local/bin/blink: Text file busy".  If so, you need to kill the currently running blink and try again.  See "killing blink" below.

2. Set up root's crontab to automatically start blink at boot time:

        sudo crontab -e
Add the line "@reboot sleep 10;/usr/local/bin/blink" near the beginning of the file.  Save and exit.  If you ever want to un-install blink, enter that command again and delete the line.

3. Test the package:

        sudo /usr/local/bin/blink

After a few seconds watching the blinking LED, ground XIO-P7 and watch CHIP shut down.  Be sure to un-ground it afterwards.  Restart CHIP, and when it has completed its reboot, watch the status LED start to blink again.

Thanks to Efreak, blink can also be invoked as:

        sudo /usr/local/bin/blink 1000000 1000000

where the first number is the number of microseconds for the LED to stay on, and the second number is the number of microseconds for the LED stay off.  So you can save power by adjusting the duty cycle:

        sudo /usr/local/bin/blink 200000 1800000

## Build from source

1. If you haven't set up your CHIP to be able to compile C programs, perform [these instructions](http://wiki.geeky-boy.com/w/index.php?title=CHIP_do_once) up to and including installing gcc.

2. Get the source files onto CHIP:

        mkdir blink
        cd blink
        wget -Oblink.c http://fordsfords.github.io/blink/blink.c
        wget -Obld.sh http://fordsfords.github.io/blink/bld.sh
        chmod +x bld.sh
(Note: you could alternately use "git" download the whole project, but CHIP doesn't come with "git" pre-installed, so this is easier.)

3. Build the package:

        ./bld.sh
(Uses sudo to write the executable into /usr/local/bin; sudo will typically prompt for your password.)

## Killing Blink

If you are running a recent enough version of blink, it creates the file "/tmp/blink.pid" containing the PID of the blink process.  If this file exists, you can kill blink with:

        sudo kill $(cat /tmp/blink.pid)

If your version is too old for that to work, enter:

        ps aux | egrep "[b]link"
It will typically list two processes; the second is the one you want to kill.  The second column in the "ps" output is the process ID (an integer, typically less than 1000).  For example:

        $ ps aux | egrep "[b]link"
        . . .
        root 368 0.0  0.1 1352   740 ? S 09:17 0:00 /usr/local/bin/blink
        $ kill 368

## Random Notes

1. The blink program requires root privileges to control the status LED and read the GPIO line.  The instructions above assume you are running it from root's crontab.  If you want to be able to run blink as a normal user, you can set the "SUID" bit on the executable as follows:

        sudo chmod +s /usr/local/bin/blink
I'm not sure why one would want to do this with blink as written, but feel free to take the blink program apart and put it back together to perform some other awesome purpose.  Setting SUID would allow an interactive user or a web server to run it without special privileges.

2. As long as the status LED continues to blink, you know that your CHIP is still running.  But if you are running some useful application, the blinking LED does not necessarily give you a good indication of the overall health of your system.  Basically, blink shows that the OS is still running, but your application may have crashed.

3. There are often ways of automatically monitoring the health of applications.  At a crude level, you can periodically run the "ps" command and at least make sure the process itself is still running.  Even better would be to be able to "poke" the application in some way to produce an expected result (like maybe sending it a signal and writing the application to write a message to a log file).  You could build this capability into blink, and if it detects a failure, change the blink rate of the LED (like to 3 pulses per second).  This still won't tell you *what* is wrong, but at least it narrows things down a bit.

## Release Notes

* 24-Jan-2016

    Initial pre-release.

* 17-Feb-2016

    Added binary executable to package.  Updated quickstart to use it.  Made a few more improvements to documentation.  Also changed the 1 second sleep to 1 million microseconds to make it easier to use a faster blink rate.  Also added /tmp/blink.pid file.

* 21-Feb 2016

    Merged in Efreak's ontime/offtime
