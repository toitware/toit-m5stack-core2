// Copyright (C) 2020 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import bitmap show *
import color_tft show *
import font show *
import font_x11_adobe.sans_10 as sans_10
import font_x11_adobe.sans_24_bold as sans_24_bold
import gpio
import m5stack_core2
import pixel_display show *
import pixel_display.histogram show TrueColorHistogram
import pixel_display.texture show *
import pixel_display.true_color show *
import spi

main:
  // Create the power object and initialize the power config
  // to its default values.  Resets the LCD display and switches
  // on the LCD backlight and the green power LED.
  device := m5stack_core2.Device

  // Get TFT driver.
  tft := device.display

  tft.background = get_rgb 0x12 0x03 0x25
  width := 320
  height := 240
  sans := Font [sans_10.ASCII]
  sans_big := Font [sans_24_bold.ASCII]
  sans_big_context := tft.context --landscape --color=WHITE --font=sans_big
  sans_big_blue := tft.context --landscape --color=(get_rgb 0x40 0x40 0xff) --font=sans_big
  sans_context := tft.context --landscape --color=WHITE --font=sans

  ctr := tft.text (sans_big_context.with --alignment=TEXT_TEXTURE_ALIGN_RIGHT) 160 25 "00000"
  ctr_small := tft.text sans_context 160 25 "000"

  hello := tft.text sans_big_blue 80 80 "Hello, Toit!"

  // A red histogram stacked on a grey one, so that we can show values
  // that are too high in a different colour.

  histo_context := tft.context --color=WHITE --translate_x=19 --translate_y=130
  histo_transform := histo_context.transform
  red_histo := TrueColorHistogram  1 -20 50 40 histo_transform 1.0 (get_rgb 0xe0 0x20 0x10)
  grey_histo := TrueColorHistogram 1  20 50 50 histo_transform 1.0 (get_rgb 0xe0 0xe0 0xff)
  tft.add red_histo
  tft.add grey_histo
  x_axis := tft.filled_rectangle histo_context -10 70 70 1
  y_axis := tft.filled_rectangle histo_context 0 0 1 80

  tft.draw

  last := Time.monotonic_us
  while true:
    sleep --ms=1  // Avoid watchdog.
    ctr.text = "$(%05d last / 1000000)"
    ctr_small.text = "$(%03d (last % 1000000) / 1000)"
    tft.draw
    next := Time.monotonic_us
    // Scale frame time by some random factor and display it on the histogram.
    diff := (next - last) / 800
    grey_histo.add diff
    red_histo.add diff - 50
    last = next
