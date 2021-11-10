// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import gpio
import m5stack_core2

main:
  clock := gpio.Pin 22
  data := gpio.Pin 21

  // Create the power object and initialize the power config
  // to its default values.  Resets the LCD display and switches
  // on the LCD backlight and the green power LED.
  power := m5stack_core2.Power --clock=clock --data=data

  if power.external_power_acin_exists:
    print "ACIN exists"
  if power.external_power_acin_usable:
    print "ACIN usable"
  if power.external_power_vbus_exists:
    print "VBUS exists"
  if power.external_power_vbus_usable:
    print "VBUS usable"
