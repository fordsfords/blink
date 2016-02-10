# blink
CHIP program to blink status light and shut down when XIO-P7 is grounded.

## License

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

You can find blink at:

* User documentation (this README): https://github.com/fordsfords/blink/tree/gh-pages

Note: the "gh-pages" branch is considered to be the current stable release.  The "master" branch is the development cutting edge.

## Quick Start

1. If you haven't set up your CHIP to be able to compile C programs, perform [these instructions](http://wiki.geeky-boy.com/w/index.php?title=CHIP_do_once) up to and including installing gcc.

2. Get the files onto CHIP:

        mkdir blink
        cd blink
        wget http://fordsfords.github.io/blink/blink.c
        wget http://fordsfords.github.io/blink/bld.sh
        chmod +x bld.sh

3. Build the package:

        ./bld.sh
(Uses "sudo" so will prompt for CHIP's password.)

4. Test the package:

        sudo /usr/local/bin/blink
(After a few seconds watching the blinking light, ground XIO-P7 and watch CHIP shut down.  Be sure to un-ground it afterwards.)

5. Set up root's crontab to automatically start blink at boot time:

        sudo crontab -e
(Add the line "@reboot sleep 10;/usr/local/bin/blink" near the beginning of the file.  Save and exit.)

6. Reboot CHIP to start blink as a background process:

        sudo shutdown -r now
(CHIP reboots and status LED starts blinking automatically.)


## Release Notes

* 0.1 (24-Jan-2016)

    Initial pre-release.
