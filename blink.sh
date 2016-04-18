#!/bin/sh
# Copyright 2016 Steven Ford http://geeky-boy.com and licensed
# "public domain" style under
# [CC0](http://creativecommons.org/publicdomain/zero/1.0/): 
# 
# To the extent possible under law, the contributors to this project have
# waived all copyright and related or neighboring rights to this work.
# In other words, you can use this code for any purpose without any
# restrictions.  This work is published from: United States.  The project home
# is https://github.com/fordsfords/blink/tree/gh-pages


# Turn on LED with "set_led 1".  Turn it off with "set_led 0".
set_led()
{
  if [ "$1" = "1" ]; then :
    /usr/sbin/i2cset -f -y 0 0x34 0x93 0x1
  elif [ "$1" = "0" ]; then :
    /usr/sbin/i2cset -f -y 0 0x34 0x93 0x0
  else :
    echo "Usage: set_led 1|0" >&2
    exit 1
  fi
}

button_not_pressed()
{
  BUTTON=`i2cget -f -y 0 0x34 0x4a`
  if [ "$BUTTON" = "0x00" ]; then :
    return 0  # Button not pressed, return 0 for success.
  elif [ "$BUTTON" = "0x02" ]; then :
    return 1  # Button not pressed, return 1 for fail.
  else :
    echo "button_not_pressed: unrecognized i2get output '$BUTTON'" >&2
    exit 1
  fi
}

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

sleep 10

LED=0
while button_not_pressed; do :
  sleep 1
  set_led $LED
  LED=`expr 1 - $LED`
done

shutdown now
