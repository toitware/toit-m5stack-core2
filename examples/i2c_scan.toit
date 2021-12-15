// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import m5stack_core2
import i2c
import gpio

main:
  // This also powers on the touch circuitry, so you can see it in the I2C
  // scan.
  device := m5stack_core2.Device
  device.i2c_bus.scan.do:
    desc := KNOWN_IDS.get it --if_absent=: ""
    print "0x$(%02x it) $desc"

KNOWN_IDS ::= {
  0x34: "AXP192 power controller",
  0x38: "FT6336 touch controller",
}
