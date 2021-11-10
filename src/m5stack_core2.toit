import gpio
import i2c
import axp192 show *

class Power:
  device /i2c.Device

  constructor --clock/gpio.Pin --data/gpio.Pin:
    bus := i2c.Bus --scl=clock --sda=data --frequency=400_000

    if not bus.scan.contains 0x68:
      throw "AXP192 not found on I2C bus"

    device = bus.device 0x68

    set_defaults

  /// Set voltage to ESP32.  Should be between 3V and 3.4V.
  esp32_voltage mv/int -> none:
    if not 3000 <= mv <= 3400: throw "OUT_OF_RANGE"
    set_bits device DC_DC1_VOLTAGE_SETTING_REGISTER --mask=DC_DC_VOLTAGE_SETTING_MASK
      dc_dc_millivolt_to_register mv

  /// Set voltage to LCD backlight.  Should be between 2.5V and 3.3V
  backlight_voltage mv/int -> none:
    set_bits device DC_DC3_VOLTAGE_SETTING_REGISTER --mask=DC_DC_VOLTAGE_SETTING_MASK
      dc_dc_millivolt_to_register mv

  /// Set peripheral voltage: LCD logic and SD card.
  peripheral_voltage mv/int -> none:
    set_bits device LDO2_3_VOLTAGE_SETTING_REGISTER --mask=LDO2_VOLTAGE_MASK
      ldo2_millivolt_to_register mv

  /// Set vibrator power voltage.
  vibrator_voltage mv/int -> none:
    set_bits device LDO2_3_VOLTAGE_SETTING_REGISTER --mask=LDO3_VOLTAGE_MASK
      ldo3_millivolt_to_register mv

  /// Enable charging of backup battery at given target millivolts and
  ///   microamperes.
  backup_battery_charging --disable/bool=false --mv/int=3000 --ua/int=200 -> none:
    backup_mask := BACKUP_BATTERY_CHARGING_ENABLED
                 | BACKUP_BATTERY_CHARGING_TARGET_VOLTAGE_MASK
                 | BACKUP_BATTERY_CHARGING_CURRENT_MASK
    backup_value := disable ? BACKUP_BATTERY_CHARGING_DISABLED : BACKUP_BATTERY_CHARGING_ENABLED
    if mv == 2500:
      backup_value |= BACKUP_BATTERY_CHARGING_TARGET_2_5
    else if mv == 3000:
      backup_value |= BACKUP_BATTERY_CHARGING_TARGET_3_0
    else if mv == 3100:
      backup_value |= BACKUP_BATTERY_CHARGING_TARGET_3_1
    else:
      throw "Invalid voltage"
    if ua == 50:
      backup_value |= BACKUP_BATTERY_CHARGING_CURRENT_50
    else if ua == 100:
      backup_value |= BACKUP_BATTERY_CHARGING_CURRENT_100
    else if ua == 200:
      backup_value |= BACKUP_BATTERY_CHARGING_CURRENT_200
    else if ua == 400:
      backup_value |= BACKUP_BATTERY_CHARGING_CURRENT_400
    else:
      throw "Invalid current"
    set_bits device BACKUP_BATTERY_CHARGE_CONTROL_REGISTER backup_value --mask=backup_mask


  /// Enable internal charging at given target millivolts and
  ///   milliamperes.  Charging ends when the current falls to
  ///   10% or 15% of the target milliamperes.  If neither is
  ///   specified the setting is not changed (it defaults to 10%).
  /// $ma should be between 100mA and 1320mA, default is 780mA.
  /// $target_mv should be 4100mV, 4150mV, 4200mV, or 4360mV, default is 4200mV.
  battery_internal_charging --on/bool=true --off/bool=(not on) --target_mv/int=4200 --ma/int=780 --end_charging_at_10_percent/bool=false --end_charging_at_15_percent/bool=false:
    set_end := end_charging_at_10_percent or end_charging_at_15_percent
    mask := CHARGE_INTERNAL_ENABLE_MASK
          | CHARGE_INTERNAL_TARGET_VOLTAGE_MASK
          | CHARGE_INTERNAL_CURRENT_MASK
    value := off ? CHARGE_INTERNAL_DISABLE : CHARGE_INTERNAL_ENABLE
    if end_charging_at_15_percent:
      mask |= CHARGE_INTERNAL_END_CURRENT_MASK
      value |= CHARGE_INTERNAL_END_CURRENT_15
    else if end_charging_at_10_percent:
      mask |= CHARGE_INTERNAL_END_CURRENT_MASK
      value |= CHARGE_INTERNAL_END_CURRENT_10
    value |= charge_internal_milliamp_to_register ma
    value |= charge_internal_target_millivolts_to_register target_mv
    set_bits device CHARGE_CONTROL_REGISTER_1 value --mask=mask

  /// Set GPIO 0 to either floating or grounded.
  gpio0 --floating=true --grounded=(not floating) -> none:
    if grounded:
      clear_bits device GPIO_2_0_SIGNAL_STATUS_REGISTER GPIO_0_WRITE_OUTPUT
    else:
      set_bits device GPIO_2_0_SIGNAL_STATUS_REGISTER GPIO_0_WRITE_OUTPUT

  /// LED is switched on by pulling down the cathode with GPIO 1.
  led --on/bool=true --off/bool=(not on) -> none:
    if off:
      set_bits device GPIO_2_0_SIGNAL_STATUS_REGISTER GPIO_1_WRITE_OUTPUT
    else:
      clear_bits device GPIO_2_0_SIGNAL_STATUS_REGISTER GPIO_1_WRITE_OUTPUT

  /// LED reset line is attached to GPIO4.  Set to 0 (pulled low) or 1 (floating with pull-up).
  led_reset value/int -> none:
    if value == 1:
      set_bits device GPIO_4_3_SIGNAL_STATUS_REGISTER GPIO_4_WRITE_OUTPUT
    else:
      clear_bits device GPIO_4_3_SIGNAL_STATUS_REGISTER GPIO_4_WRITE_OUTPUT

  /// Speaker is switched on by floating GPIO 2 and letting the pull-up do its
  ///   job.
  speaker --on/bool=true --off/bool=(not on) -> none:
    if off:
      clear_bits device GPIO_2_0_SIGNAL_STATUS_REGISTER GPIO_2_WRITE_OUTPUT
    else:
      set_bits device GPIO_2_0_SIGNAL_STATUS_REGISTER GPIO_2_WRITE_OUTPUT

  // Switch power on peripherals.
  peripherals --on/bool=true --off/bool=(not on) -> none:
    power_ POWER_OUTPUT_LDO2 off

  // Switch power on vibrator.
  vibrator --on/bool=true --off/bool=(not on) -> none:
    power_ POWER_OUTPUT_LDO3 off

  // Switch power on DC1.
  dc_dc1 --on/bool=true --off/bool=(not on) -> none:
    power_ POWER_OUTPUT_DC_DC1 off

  // Switch power on DC2.
  dc_dc2 --on/bool=true --off/bool=(not on) -> none:
    power_ POWER_OUTPUT_DC_DC2 off

  // Switch power on LCD backlight.
  backlight --on/bool=true --off/bool=(not on) -> none:
    power_ POWER_OUTPUT_DC_DC3 off

  // Switch on 5V boost chip.
  boost_enable --on/bool=true --off/bool=(not on) -> none:
    power_ POWER_OUTPUT_EXTEN off

  power_ pin/int off/bool -> none:
    if off:
      clear_bits device POWER_OUTPUT_CONTROL_REGISTER pin
    else:
      set_bits device POWER_OUTPUT_CONTROL_REGISTER pin

  /// Pick one of the functions for GPIO4.
  gpio_4 --on/bool=false --off/bool=(not on) --external_charging_control/bool=false --nmos_open_drain_output/bool=false --universal_input/bool=false -> none:
    check := external_charging_control ? 1 : 0
    check += nmos_open_drain_output ? 1 : 0
    check += universal_input ? 1 : 0
    if check != 1: throw "Specify exactly one GPIO function"
    mask := GPIO_4_3_FEATURES_MASK | GPIO_4_FUNCTION_MASK
    value := GPIO_4_3_FEATURES_ENABLE
    value |= external_charging_control ? GPIO_4_EXTERNAL_CHARGING_CONTROL : 0
    value |= nmos_open_drain_output ? GPIO_4_NMOS_OPEN_DRAIN_OUTPUT : 0
    value |= universal_input ? GPIO_4_UNIVERSAL_INPUT_PORT : 0
    set_bits device GPIO_4_3_FUNCTION_CONTROL_REGISTER value --mask=mask

  /// Pick one of the functions for GPIO3.
  gpio_3 --on/bool=false --off/bool=(not on) --external_charging_control/bool=false --nmos_open_drain_output/bool=false --universal_input/bool=false --adc_input/bool=false -> none:
    check := external_charging_control ? 1 : 0
    check += nmos_open_drain_output ? 1 : 0
    check += universal_input ? 1 : 0
    check += adc_input ? 1 : 0
    if check != 1: throw "Specify exactly one GPIO function"
    mask := GPIO_4_3_FEATURES_MASK | GPIO_3_FUNCTION_MASK
    value := GPIO_4_3_FEATURES_ENABLE
    value |= external_charging_control ? GPIO_3_EXTERNAL_CHARGING_CONTROL : 0
    value |= nmos_open_drain_output ? GPIO_3_NMOS_OPEN_DRAIN_OUTPUT : 0
    value |= universal_input ? GPIO_3_UNIVERSAL_INPUT_PORT : 0
    value |= adc_input ? GPIO_3_ADC_INPUT : 0
    set_bits device GPIO_4_3_FUNCTION_CONTROL_REGISTER value --mask=mask

  /**
  Set parameters related to reboot.
  $boot_time_ms must be 128ms, 512ms, 1000ms or 2000ms.  Hardware default is 512ms.
  $long_press_time_ms must be 1000ms, 1500ms, 2000ms, or 2500ms.  Hardware default is 1500ms.
  $long_press_shutdown is true for shutdown, false for startup.
  $pwrok_signal_delay_ms must be 32ms, or 64ms.  Hardware default is 64ms.
  4shutdown_duration_s must be 4s, 6s, 8s, or 10s.  Hardware default is 6s.
  */
  pek_parameter --boot_time_ms/int?=null --long_press_time_ms/int?=null --long_press_shutdown/bool?=null --pwrok_signal_delay_ms/int?=null --shutdown_duration_s/int?=null -> none:
    value := 0
    mask := 0
    if boot_time_ms:
      mask = BOOT_TIME_MASK
      if boot_time_ms == 128:
        value = BOOT_TIME_128_MS
      else if boot_time_ms == 512:
        value = BOOT_TIME_512_MS
      else if boot_time_ms == 1000:
        value = BOOT_TIME_1000_MS
      else if boot_time_ms == 2000:
        value = BOOT_TIME_2000_MS
      else:
        throw "Boot time must be 128ms, 512ms, 1000ms, or 2000ms."
    if long_press_time_ms:
      mask |= LONG_PRESS_TIME_MASK
      if long_press_time_ms == 1000:
        value |= LONG_PRESS_TIME_1000_MS
      else if long_press_time_ms == 1500:
        value |= LONG_PRESS_TIME_1500_MS
      else if long_press_time_ms == 2000:
        value |= LONG_PRESS_TIME_2000_MS
      else if long_press_time_ms == 2500:
        value |= LONG_PRESS_TIME_2500_MS
      else:
        throw "Long press time must be 1000ms, 1500ms, 2000ms, or 2500ms"
    if long_press_shutdown != null:
      mask |= LONG_PRESS_FUNCTION_MASK
      if long_press_shutdown:
        value |= LONG_PRESS_AUTOMATIC_SHUTDOWN
      else:
        value |= LONG_PRESS_TURN_ON
    if pwrok_signal_delay_ms != null:
      mask |= PWROK_SIGNAL_DELAY_MASK
      if pwrok_signal_delay_ms == 32:
        value |= PWROK_SIGNAL_32
      else if pwrok_signal_delay_ms == 64:
        value |= PWROK_SIGNAL_64
      else:
        throw "PWROK signal delay must be 32ms or 64ms"
    if shutdown_duration_s != null:
      if shutdown_duration_s & 1 != 0 or not 4 <= shutdown_duration_s <= 10:
        throw "Shutdown duration must be 4s, 6s, 8s, or 10s"
      mask |= SHUTDOWN_DURATION_MASK
      value |= (shutdown_duration_s - 4) >> 1

    set_bits device PEK_PARAMETER_SETTING_REGISTER value --mask=mask

  /// Enable/disable battery voltage ADC.
  adc_battery_voltage --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_BATTERY_VOLTAGE (not disable)

  /// Enable/disable battery current ADC.
  adc_battery_current --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_BATTERY_CURRENT (not disable)

  /// Enable/disable ACIN voltage ADC.
  adc_acin_voltage --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_ACIN_VOLTAGE (not disable)

  /// Enable/disable ACIN current ADC.
  adc_acin_current --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_ACIN_CURRENT (not disable)

  /// Enable/disable VBUS voltage ADC.
  adc_vbus_voltage --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_VBUS_VOLTAGE (not disable)

  /// Enable/disable VBUS current ADC.
  adc_vbus_current --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_VBUS_CURRENT (not disable)

  /// Enable/disable APS voltage ADC.
  adc_aps_voltage --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_APS_VOLTAGE (not disable)

  /// Enable/disable TS pin ADC.
  adc_ts_pin --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_1 ADC_ENABLE_TS_PIN (not disable)

  /// Enable/disable internal temperature ADC.
  adc_internal_temperature --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_2 ADC_ENABLE_INTERNAL_TEMPERATURE (not disable)

  /// Enable/disable ADC on GPIO0.
  adc_gpio_0 --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_2 ADC_ENABLE_GPIO_0 (not disable)

  /// Enable/disable ADC on GPIO1.
  adc_gpio_1 --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_2 ADC_ENABLE_GPIO_1 (not disable)

  /// Enable/disable ADC on GPIO2.
  adc_gpio_2 --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_2 ADC_ENABLE_GPIO_2 (not disable)

  /// Enable/disable ADC on GPIO3.
  adc_gpio_3 --enable/bool=false --disable/bool=(not enable) -> none:
    adc_control_ ADC_ENABLE_SETTING_REGISTER_2 ADC_ENABLE_GPIO_3 (not disable)

  adc_control_ register/int bit/int set/bool -> none:
    if set:
      set_bits device register bit
    else:
      clear_bits device register bit

  ldo_output_voltage mv/int -> none:
    set_bits device GPIO_0_LDO_MODE_OUTPUT_VOLTAGE_SETTING_REGISTER
      --mask=LDO_OUTPUT_VOLTAGE_MASK
      ldo_output_voltage_to_register mv

  /// Specify one of $usb_or_battery or $outside power modes.
  bus_power_mode --usb_or_battery=true --outside=(not usb_or_battery) -> none:
    if outside:
      boost_enable --off
      set_bits device GPIO_0_CONTROL_REGISTER GPIO_CONTROL_UNIVERSAL_INPUT_FUNCTION --mask=GPIO_CONTROL_MASK
    else:
      ldo_output_voltage 3300
      set_bits device GPIO_0_CONTROL_REGISTER GPIO_CONTROL_LOW_NOISE_LDO --mask=GPIO_CONTROL_MASK
      boost_enable --on

  external_power_acin_exists -> bool:
    return power_flag_ POWER_STATUS_ACIN_EXISTS

  external_power_acin_usable -> bool:
    return power_flag_ POWER_STATUS_ACIN_USABLE

  external_power_vbus_exists -> bool:
    return power_flag_ POWER_STATUS_VBUS_EXISTS

  external_power_vbus_usable -> bool:
    return power_flag_ POWER_STATUS_VBUS_USABLE

  external_power_vbus_higher_than_vhold -> bool:
    return power_flag_ POWER_STATUS_VBUS_HIGHER_THAN_VHOLD

  external_power_in_pcb_short -> bool:
    return power_flag_ POWER_STATUS_POWER_IN_PCB_SHORT

  external_power_acin_vbus_trigger -> bool:
    return power_flag_ POWER_STATUS_ACIN_VBUS_TRIGGER

  power_flag_ bit/int -> bool:
    reg0 := device.registers.read_bytes POWER_STATUS_REGISTER 1
    print "Power status 0x$(%02x reg0[0])"
    return reg0[0] & bit != 0

  set_defaults -> none:
    // VBUS limit off, clear all other bits, leave bit 2 alone.
    set_bits device VBUS_IPSOUT_PATH_SETTING_REGISTER VBUS_CURRENT_LIMIT_CONTROL_ENABLE_ON --mask=0b1111_1011

    // GPIO1 and GPIO2 open drain output.
    set_bits device GPIO_1_CONTROL_REGISTER GPIO_CONTROL_NMOS_OPEN_DRAIN_OUTPUT --mask=GPIO_CONTROL_MASK
    set_bits device GPIO_2_CONTROL_REGISTER GPIO_CONTROL_NMOS_OPEN_DRAIN_OUTPUT --mask=GPIO_CONTROL_MASK

    backup_battery_charging --mv=3000 --ua=200
    esp32_voltage 3350
    backlight_voltage 2800
    peripheral_voltage 3300
    vibrator_voltage 2000
    led --on
    peripherals --on
    backlight --on
    battery_internal_charging --target_mv=4200 --ma=1320
    gpio_4 --nmos_open_drain_output
    pek_parameter
      --boot_time_ms=512
      --long_press_time_ms=1000
      --long_press_shutdown=false
      --pwrok_signal_delay_ms=64
      --shutdown_duration_s=4
    adc_battery_voltage --enable
    adc_battery_current --enable
    adc_acin_voltage --enable
    adc_acin_current --enable
    adc_vbus_voltage --enable
    adc_vbus_current --enable
    adc_aps_voltage --enable
    adc_ts_pin --enable

    led_reset 0
    sleep --ms=100
    led_reset 1

    bus_power_mode --usb_or_battery

    vibrator --on
    print "Vibrator on"
    sleep --ms=2000
    vibrator --off
    print "Vibrator off"