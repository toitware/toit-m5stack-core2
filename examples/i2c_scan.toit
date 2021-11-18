import m5stack_core2
import i2c
import gpio

main:
  clock := gpio.Pin 22
  data := gpio.Pin 21
  // This also powers on the touch circuitry, so you can see it in the I2C
  // scan.
  power := m5stack_core2.Power --clock=clock --data=data

  bus := i2c.Bus --scl=clock --sda=data --frequency=400_000
  bus.scan.do:
    desc := KNOWN_IDS.get it --if_absent=: ""
    print "0x$(%02x it) $desc"

KNOWN_IDS ::= {
  0x34: "AXP192 power controller",
  0x38: "FT6336 touch controller",
}
