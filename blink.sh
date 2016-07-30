#!/bin/sh
# blink.sh -- version 24-Jul-2016
# Normally installed as a service started at bootup.
# See https://github.com/fordsfords/blink/tree/gh-pages
#
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
  if [ -n "$BLINK_STATUS" ]; then :
    /usr/sbin/i2cset -f -y 0 0x34 0x93 $1
  fi

  if [ -n "$BLINK_GPIO" ]; then :
    gpio_output $BLINK_GPIO $1
  fi
}

# Return 0 (success) if shutdown NOT requested.
# Return 1 (fail) if shutdown IS requested.
shutdown_check()
{
  if [ -n "$MON_RESET" ]; then :
    REG4AH=`i2cget -f -y 0 0x34 0x4a`  # Read AXP209 register 4AH
    BUTTON=$((REG4AH & 0x02))  # mask off the short press bit
    if [ $BUTTON -eq 2 ]; then :
      SHUTDOWN_REASON="reset short press"
      return 1  # Short button press, return 1 for shutdown requested (fail).
    fi
  fi

  if [ -n "$MON_BATTERY" ]; then :
    REGB9H=`i2cget -f -y 0 0x34 0xb9`  # Read AXP209 register B9H
    PERC_CHG=$(($REGB9H))  # convert to decimal
    if [ $PERC_CHG -lt $MON_BATTERY ]; then :
      SHUTDOWN_REASON="battery at $PERC_CHG"
      return 1  # Battery charge below threshold, return 1 for shutdown requested (fail).
    fi
  fi

  if [ -n "$MON_GPIO" ]; then :
    gpio_input $MON_GPIO; VAL=$?
    if [ $VAL -eq $MON_GPIO_VALUE ]; then :
      SHUTDOWN_REASON="gpio $MON_GPIO is $VAL"
      return 1  # GPIO value is active, return 1 for shutdown requested (fail).
    fi
  fi

  return 0  # No shutdown requests are pending, return 0 for no shutdown (success).
}  # shutdown_check


blink_cleanup()
{
  if [ -n "$MON_GPIO" ]; then gpio_unexport $MON_GPIO; fi
  if [ -n "$BLINK_GPIO" ]; then gpio_unexport $BLINK_GPIO; fi
}


blink_stop()
{
  blink_cleanup
  echo "blink: stopped" `date` >>/var/tmp/blink.log
  exit
}


PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
cat /dev/null >/var/tmp/blink.log  # clear log file
echo "blink: starting" `date` >>/var/tmp/blink.log

export MON_RESET=
export MON_GPIO=
export MON_GPIO_VALUE=0  # if MON_GPIO supplied, default to active-0.
export MON_BATTERY=
export BLINK_STATUS=
export BLINK_GPIO=
export DEBUG=

SHUTDOWN_REASON="unknown"
PREV_CHG=-1

if [ -f /usr/local/etc/blink.cfg ]; then :
  source /usr/local/etc/blink.cfg
else :
  MON_RESET=1
  BLINK_STATUS=1
fi

if [ -n "$MON_RESET" -o -n "$MON_BATTERY" -o -n "$BLINK_STATUS" ]; then :
  # Need to communicate with AXP209 via I2C commands
  if [ ! -x /usr/sbin/i2cget -o ! -x /usr/sbin/i2cset ]; then :
    echo "blink: need i2c-tools for MON_RESET, MON_BATTERY, or BLINK_STATUS" >>/var/tmp/blink.log
    echo "Use: sudo apt-get install i2c-tools" >>/var/tmp/blink.log
    cat /var/tmp/blink.log >&2
    exit 1
  fi
fi

# If GPIOs are going to be used, set them up.
if [ -n "$MON_GPIO" -o -n "$BLINK_GPIO" ]; then :
  if [ ! -f /usr/local/bin/gpio.sh ]; then :
    echo "blink: need /usr/local/bin/gpio.sh for MON_GPIO or BLINK_GPIO" >>/var/tmp/blink.log
    echo "See https://github.com/fordsfords/gpio_sh/tree/gh-pages" >>/var/tmp/blink.log
    cat /var/tmp/blink.log >&2
    exit 1
  fi

  source /usr/local/bin/gpio.sh

  if [ -n "$MON_GPIO" ]; then :
    gpio_export $MON_GPIO; ST=$?
    if [ $ST -ne 0 ]; then :
      echo "blink: cannot export $MON_GPIO for monitoring" >>/var/tmp/blink.log
      cat /var/tmp/blink.log >&2
      if [ -z "$DEBUG" ]; then exit 1; fi  # if debug, don't exit if export fails.
    fi
    gpio_direction $MON_GPIO in
  fi

  if [ -n "$BLINK_GPIO" ]; then :
    gpio_export $BLINK_GPIO; ST=$?
    if [ $ST -ne 0 ]; then :
      echo "blink: cannot export $BLINK_GPIO for blinking" >>/var/tmp/blink.log
      cat /var/tmp/blink.log >&2
      if [ -z "$DEBUG" ]; then :  # if debug, don't exit if export fails.
        if [ -n "$MON_GPIO" ]; then gpio_unexport $MON_GPIO; fi
        exit 1
      fi
    fi
    gpio_direction $BLINK_GPIO out
  fi
fi

# Write PID of running script to /tmp/blink.pid
echo $$ >/tmp/blink.pid

# Respond to control-c, kill, and service stop
trap "blink_stop" 1 2 3 15
if [ -n "$DEBUG" ]; then echo "blink: DEBUG=$DEBUG" `date` >>/var/tmp/blink.log; fi

LED=0
# Loop until detects short press of reset button
while shutdown_check; do :
  sleep 1
  set_led $LED
  LED=`expr 1 - $LED`  # flip LED 1->0, 0->1
done

echo $SHUTDOWN_REASON `date` >>/var/tmp/blink.log

blink_cleanup

if [ -z "$DEBUG" ]; then :  # don't shutdown in debug mode
  shutdown now
fi
