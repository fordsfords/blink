#!/bin/sh
# blink.sh -- version: "17-Sep-2016"
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


blink_cleanup()
{
  # Only un-export ports that we actually exported.
  if [ -n "$MON_GPIO_SET" ]; then gpio_unexport $MON_GPIO; fi
  if [ -n "$BLINK_GPIO_SET" ]; then gpio_unexport $BLINK_GPIO; fi
  if [ -n "$WARN_BATTERY_GPIO_SET" ]; then gpio_unexport $WARN_BATTERY_GPIO; fi
  if [ -n "$WARN_TEMPERATURE_GPIO_SET" ]; then gpio_unexport $WARN_TEMPERATURE_GPIO; fi
}


blink_stop()
{
  blink_cleanup
  echo "blink: stopped"
  exit
}

blink_error()
{
  blink_cleanup
  while [ -n "$1" ]; do :
    echo "blink: $1"
    shift    # get next error string into $1
  done
  exit 1
}


check_i2c_installed()
{
  # Need to communicate with AXP209 via I2C commands
  if [ ! -x /usr/sbin/i2cget -o ! -x /usr/sbin/i2cset ]; then :
    blink_error "need i2c-tools for MON_RESET" "Use: sudo apt-get install i2c-tools"
  fi
}

check_gpio_installed()
{
  if [ ! -f /usr/local/bin/gpio.sh ]; then :
    blink_error "need /usr/local/bin/gpio.sh for GPIO feature" "See https://github.com/fordsfords/gpio_sh/tree/gh-pages"
  fi
}


read_config()
{
  MON_RESET=
  MON_GPIO=
  MON_GPIO_VALUE=0

  MON_BATTERY=
  WARN_BATTERY=
  WARN_BATTERY_GPIO=
  WARN_BATTERY_GPIO_VALUE=0

  HAVE_TEMP_SENSOR=
  MON_TEMPERATURE=
  WARN_TEMPERATURE=
  WARN_TEMPERATURE_GPIO=
  WARN_TEMPERATURE_GPIO_VALUE=0

  BLINK_STATUS=
  BLINK_GPIO=

  MON_GPIO_SET=
  LINK_GPIO_SET=
  WARN_BATTERY_GPIO_SET=
  WARN_TEMPERATURE_GPIO_SET=

  SHUTDOWN_SCRIPT=

  [ $# -eq 1 ] && CFG=$1 || CFG=/usr/local/etc/blink.cfg

  if [ -f $CFG ]; then :
    source $CFG
  else :
    MON_RESET=1
    BLINK_STATUS=1
  fi
}


# Group init functions related to GPIO

init_mon_gpio()
{
  if [ -n "$MON_GPIO" ]; then :
    check_gpio_installed

    gpio_export $MON_GPIO; ST=$?
    if [ $ST -ne 0 ]; then :
      blink_error "cannot export $MON_GPIO for monitoring"
    fi
    MON_GPIO_SET=1
    gpio_direction $MON_GPIO in

    MON_GPIO_SAMPLE=
  fi
}

sample_mon_gpio()
{
  if [ -n "$MON_GPIO" ]; then :
    gpio_input $MON_GPIO; VAL=$?

    MON_GPIO_SAMPLE=$VAL
  fi
}

check_shut_gpio()
{
  if [ -n "$MON_GPIO" ]; then :
    if [ $MON_GPIO_SAMPLE -eq $MON_GPIO_VALUE ]; then :
      shutdown_now "gpio($MON_GPIO)"
    fi
  fi
}


init_blink_gpio()
{
  if [ -n "$BLINK_GPIO" ]; then :
    check_gpio_installed

    gpio_export $BLINK_GPIO; ST=$?
    if [ $ST -ne 0 ]; then :
      blink_error "cannot export $BLINK_GPIO for blinking (in use?)"
    fi
    BLINK_GPIO_SET=1
    gpio_direction $BLINK_GPIO out

    GPIO_LED=1
    gpio_output $BLINK_GPIO $GPIO_LED
  fi
}

invert_blink_gpio()
{
  if [ -n "$BLINK_GPIO" ]; then :
    GPIO_LED=$(( 1 - $GPIO_LED ))
    gpio_output $BLINK_GPIO $GPIO_LED
  fi
}


# Group init functions related to I2C

init_mon_reset()
{
  if [ -n "$MON_RESET" ]; then :
    check_i2c_installed

    MON_RESET_SAMPLE=
  fi
}

sample_mon_reset()
{
  if [ -n "$MON_RESET" ]; then :
    REG4AH=$(i2cget -f -y 0 0x34 0x4a)  # Read AXP209 register 4AH
    BUTTON=$(( $REG4AH & 0x02 ))        # mask off the short press bit
    if [ $BUTTON -eq 0 ]; then :
      MON_RESET_SAMPLE=0
    else :
      MON_RESET_SAMPLE=1
    fi
  fi
}

check_shut_reset()
{
  if [ -n "$MON_RESET" ]; then :
    if [ $MON_RESET_SAMPLE -eq 1 ]; then :
      shutdown_now "reset"
    fi
  fi
}


init_mon_battery()
{
  if [ -n "$MON_BATTERY" ]; then :
    check_i2c_installed

    if [ -n "$WARN_BATTERY_GPIO" ]; then :
      check_gpio_installed
      gpio_export $WARN_BATTERY_GPIO; ST=$?
      if [ $ST -ne 0 ]; then :
        blink_error "cannot export $WARN_BATTERY_GPIO for battery warning (in use?)"
      fi
      WARN_BATTERY_GPIO_SET=1
      gpio_direction $WARN_BATTERY_GPIO out

      # Assume no warning
      WARN_BATTERY_GPIO_LEVEL=$(( 1 - $WARN_BATTERY_GPIO_VALUE ))
      gpio_output $WARN_BATTERY_GPIO $WARN_BATTERY_GPIO_LEVEL
    fi

    TS=$(expr 2 + $HAVE_TEMP_SENSOR)
    # force ADC enable for battery voltage and current
    i2cset -y -f 0 0x34 0x82 0xC$TS

    MON_BATTERY_SAMPLE_PWR=
    MON_BATTERY_SAMPLE_PERC=
    BATTERY_WARN_STATE=
  fi
}

sample_mon_battery()
{
  if [ -n "$MON_BATTERY" ]; then :
    # Get battery gauge.
    REGB9H=$(i2cget -f -y 0 0x34 0xb9)    # Read AXP209 register B9H
    MON_BATTERY_SAMPLE_PERC=$(($REGB9H))  # convert to decimal

    # On CHIP, the battery detection (bit 5, reg 01H) does not work (stuck "on"
    # even when battery is disconnected).  Also, when no battery connected,
    # the battery discharge current varies wildly (probably a floating lead).  
    # So assume the battery is NOT discharging when MicroUSB and/or CHG-IN
    # are present (i.e. when chip is "powered").
    REG00H=$(i2cget -f -y 0 0x34 0x00)    # Read AXP209 register 00H
    PWR_BITS=$(( $REG00H & 0x50 ))        # ACIN usalbe and VBUS usable bits
    if [ $PWR_BITS -ne 0 ]; then :
      MON_BATTERY_SAMPLE_PWR=1
    else
      MON_BATTERY_SAMPLE_PWR=0
    fi
  fi
}

check_shut_battery()
{
  if [ -n "$MON_BATTERY" ]; then :
    if [ $MON_BATTERY_SAMPLE_PWR -eq 0 -a \
         $MON_BATTERY_SAMPLE_PERC -lt $MON_BATTERY ]; then :
      shutdown_now "battery($MON_BATTERY_SAMPLE_PERC)"
    fi
  fi
}

check_warn_battery()
{
  if [ -n "$MON_BATTERY" -a -n "$WARN_BATTERY" ]; then :
    # Check if already in temperature warning state.
    if [ -n "$BATTERY_WARN_STATE" ]; then :
      # To prevent rapid flapping between warn and non-warn, while
      # in battery warning state, require gauge rise 2% above
      # warning level to exit warning state (adds hysteresis).
      TEST_BATTERY=$(( $WARN_BATTERY + 2 ))
      if [ $MON_BATTERY_SAMPLE_PWR -eq 0 -a \
           $MON_BATTERY_SAMPLE_PERC -lt $TEST_BATTERY ]; then :
        # Battery still in warning.  Already in warning state.
        NUM_WARNS=$(( $NUM_WARNS + 1 ))
      else :
        # Battery out of warning.  Exit warning state.
        echo "Blink: battery warning resolved."
        BATTERY_WARN_STATE=
        if [ -n "$WARN_BATTERY_GPIO" ]; then :
          WARN_BATTERY_GPIO_LEVEL=$(( 1 - $WARN_BATTERY_GPIO_VALUE ))
          gpio_output $WARN_BATTERY_GPIO $WARN_BATTERY_GPIO_LEVEL
        fi
      fi
    else :
      # Not in warning state, see if need to enter it.
      TEST_BATTERY=$(( $WARN_BATTERY ))
      if [ $MON_BATTERY_SAMPLE_PWR -eq 0 -a \
           $MON_BATTERY_SAMPLE_PERC -lt $TEST_BATTERY ]; then :
        # Battery entering warning state.
        echo "Blink: Warning: battery."
        BATTERY_WARN_STATE=1
        if [ -n "$WARN_BATTERY_GPIO" ]; then :
          WARN_BATTERY_GPIO_LEVEL=$WARN_BATTERY_GPIO_VALUE
          gpio_output $WARN_BATTERY_GPIO $WARN_BATTERY_GPIO_LEVEL
        fi
        NUM_WARNS=$(( $NUM_WARNS + 1 ))
      else :
        # Battery not in warning.
      fi
    fi
  fi
}

init_mon_temperature()
{
  if [ -n "$MON_TEMPERATURE" ]; then :
    check_i2c_installed

    if [ -n "$WARN_TEMPERATURE_GPIO" ]; then :
      check_gpio_installed
      gpio_export $WARN_TEMPERATURE_GPIO; ST=$?
      if [ $ST -ne 0 ]; then :
        blink_error "cannot export $WARN_TEMPERATURE_GPIO for temperature warning (in use?)"
      fi
      WARN_TEMPERATURE_GPIO_SET=1
      gpio_direction $WARN_TEMPERATURE_GPIO out

      # Assume no warning
      WARN_TEMPERATURE_GPIO_LEVEL=$(( 1 - $WARN_TEMPERATURE_GPIO_VALUE ))
      gpio_output $WARN_TEMPERATURE_GPIO $WARN_TEMPERATURE_GPIO_LEVEL
    fi

    MON_TEMPERATURE_SAMPLE=
    TEMPERATURE_WARN_STATE=
  fi
}

sample_mon_temperature()
{
  if [ -n "$MON_TEMPERATURE" ]; then :
    TEMPERATURE_MSB=$(i2cget -y -f 0 0x34 0x5e)
    TEMPERATURE_LSB=$(i2cget -y -f 0 0x34 0x5f)
    MON_TEMPERATURE_SAMPLE=$(( ( ($TEMPERATURE_MSB << 4) | $TEMPERATURE_LSB ) - 1447 ))
  fi
}

check_shut_temperature()
{
  if [ -n "$MON_TEMPERATURE" ]; then :
    if [ $MON_TEMPERATURE_SAMPLE -gt $MON_TEMPERATURE ]; then :
      shutdown_now "temperature($MON_TEMPERATURE_SAMPLE)"
    fi
  fi
}

check_warn_temperature()
{
  if [ -n "$MON_TEMPERATURE" -a -n "$WARN_TEMPERATURE" ]; then :
    # Check if already in temperature warning state.
    if [ -n "$TEMPERATURE_WARN_STATE" ]; then :
      # To prevent rapid flapping between warn and non-warn, while
      # in temperature warning state, require temperature drop 1.1 degree below
      # warning temperature to exit warning state (adds hysteresis).
      TEST_TEMPERATURE=$(( $WARN_TEMPERATURE - 11 ))
      if [ $MON_TEMPERATURE_SAMPLE -gt $TEST_TEMPERATURE ]; then :
        # Temperature still in warning.  Already in warning state.
        NUM_WARNS=$(( $NUM_WARNS + 1 ))
      else :
        # Temperature out of warning.  Exit warning state.
        echo "Blink: temperature warning resolved."
        TEMPERATURE_WARN_STATE=
        if [ -n "$WARN_TEMPERATURE_GPIO" ]; then :
          WARN_TEMPERATURE_GPIO_LEVEL=$(( 1 - $WARN_TEMPERATURE_GPIO_VALUE ))
          gpio_output $WARN_TEMPERATURE_GPIO $WARN_TEMPERATURE_GPIO_LEVEL
        fi
      fi
    else :
      # Not in warning state, see if need to enter it.
      TEST_TEMPERATURE=$WARN_TEMPERATURE
      if [ $MON_TEMPERATURE_SAMPLE -gt $TEST_TEMPERATURE ]; then :
        # Temperature entering warning state
        echo "Blink: Warning: temperature."
        TEMPERATURE_WARN_STATE=1
        if [ -n "$WARN_TEMPERATURE_GPIO" ]; then :
          WARN_TEMPERATURE_GPIO_LEVEL=$WARN_TEMPERATURE_GPIO_VALUE
          gpio_output $WARN_TEMPERATURE_GPIO $WARN_TEMPERATURE_GPIO_LEVEL
        fi
        NUM_WARNS=$(( $NUM_WARNS + 1 ))
      else :
        # Temperature not in warning state.
      fi
    fi
  fi
}


init_blink_status()
{
  if [ -n "$BLINK_STATUS" ]; then :
    check_i2c_installed

    STATUS_LED=1
  fi
}

invert_blink_status()
{
  if [ -n "$BLINK_STATUS" ]; then :
    STATUS_LED=$(( 1 - $STATUS_LED ))
    /usr/sbin/i2cset -f -y 0 0x34 0x93 $STATUS_LED
  fi
}


init_externals()
{
  init_mon_reset
  init_mon_gpio
  init_mon_battery
  init_mon_temperature

  init_blink_status
  init_blink_gpio
}



sample_externals()
{
  sample_mon_reset
  sample_mon_gpio
  sample_mon_battery
  sample_mon_temperature
}


check_shut()
{
  check_shut_reset
  check_shut_gpio
  check_shut_battery
  check_shut_temperature
}


check_warn()
{
  NUM_WARNS=0
  check_warn_battery
  check_warn_temperature
}


shutdown_now()
{

  [ ! -z "$SHUTDOWN_SCRIPT" ] && [ -x "$SHUTDOWN_SCRIPT" ] && $SHUTDOWN_SCRIPT '$1'
  echo "Shutdown, reason='$1'"
  which shutdown && shutdown -h now
  which poweroff && poweroff
}


warn_user()
{
  for I in 1 2 3 4; do :
    invert_blink_status

    invert_blink_gpio

    sleep 0.25
  done
}

blink_user()
{
  invert_blink_status

  invert_blink_gpio

  sleep 1
}

#########################################################################

echo "blink: starting"

# Initialize everything

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Assume we might need gpio
if [ -f /usr/local/bin/gpio.sh ]; then :
  source /usr/local/bin/gpio.sh
fi

read_config $1

init_externals  # external I/O ports

# Write PID of running script to /tmp/blink.pid
echo $$ >/run/blink.pid

# Respond to control-c, kill, and service stop
trap "blink_stop" 1 2 3 15

while true; do :
  sample_externals

  check_shut

  check_warn
  if [ $NUM_WARNS -gt 0 ]; then :
    warn_user
  else :
    blink_user
  fi
done
