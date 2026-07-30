// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import m5stack_core2

main:

  // Create the power object and initialize the power config
  // to its default values.  Resets the LCD display and switches
  // on the LCD backlight and the green power LED.
  device := m5stack_core2.Device


  if device.power.external_power_acin_exists:
    print "ACIN exists"
  if device.power.external_power_acin_usable:
    print "ACIN usable"
  if device.power.external_power_vbus_exists:
    print "VBUS exists"
  if device.power.external_power_vbus_usable:
    print "VBUS usable"
