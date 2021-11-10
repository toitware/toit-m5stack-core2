# M5Stack Core2

Useful functions for the M5Stack Core2.  Most of the
functionality relates to the AXP192 power control chip
that also controls the LCD backlight and reset lines,
and the green LED.

## Example

```
import gpio
import m5stack_core2

main:
  clock := gpio.Pin 22
  data := gpio.Pin 21

  // Create the power object and initialize the power config
  // to its default values.  Resets the LCD display and switches
  // on the LCD backlight and the green power LED.
  power := m5stack_core2.Power --clock=clock --data=data
```

