# XIAO nRF52840 Sense: first motion check

**USB readings working? Continue with the [Bluetooth streaming test](ble-motion.md).**

The confirmed board is the **Seeed Studio XIAO nRF52840 Sense**. Its onboard
LSM6DS3TR-C contains a three-axis accelerometer and three-axis gyroscope, and
the nRF52840 supports BLE. Start with USB power and the onboard sensor.
[Board reference](https://wiki.seeedstudio.com/XIAO_BLE/),
[IMU reference](https://wiki.seeedstudio.com/XIAO-BLE-Sense-IMU-Usage/).

## Set up and upload

1. Connect the board to the computer with a USB-C **data** cable.
2. Install [Arduino IDE](https://www.arduino.cc/en/software). In **File >
   Preferences > Additional Boards Manager URLs**, add:

   ```text
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```

3. In Boards Manager, install **Seeed nRF52 Boards 1.1.13** (the non-mbed package).
   Select **Seeed XIAO nRF52840 Sense** under that package and select its COM
   port. Seeed recommends this core for Bluetooth; its USB Serial support uses
   the `Adafruit_TinyUSB.h` include already present in the sketch.
   [Seeed setup and core selection](https://wiki.seeedstudio.com/XIAO_BLE/#two-arduino-libraries).
4. Install the
   [Seeed_Arduino_LSM6DS3 library 2.0.7 ZIP](https://github.com/Seeed-Studio/Seeed_Arduino_LSM6DS3/archive/refs/tags/v2.0.7.zip)
   using **Sketch > Include Library > Add .ZIP Library** if it is not already
   available. Use Seeed's library, which supports this board's onboard sensor.
5. In **Sketch > Include Library > Manage Libraries**, search for **Adafruit
   TinyUSB** and install **Adafruit TinyUSB Library** by **Adafruit** if the
   selected board package does not already provide it. Accept required
   dependencies. This supplies the sketch's `Adafruit_TinyUSB.h` header.
   [Adafruit TinyUSB library](https://github.com/adafruit/Adafruit_TinyUSB_Arduino).
6. Open [imu_check/imu_check.ino](imu_check/imu_check.ino), click **Verify**,
   then **Upload**. Open **Serial Monitor** at **115200 baud**. The diagnostic
   prints a CSV header followed by about ten rows per second.

These versions were used for the working USB and BLE checks. Record any version
changes with new captures so another developer can reproduce the setup.

This sketch targets the non-mbed core. Seeed documents a separate ArduinoBLE
path for its mbed-enabled core; this project's BLE sketch uses the non-mbed core.
[Non-mbed BLE guide](https://wiki.seeedstudio.com/XIAO-BLE-Sense-Bluetooth_Usage/),
[mbed BLE guide](https://wiki.seeedstudio.com/XIAO-BLE-Sense-Bluetooth-Usage/).

## Check the readings

The CSV columns are:

```text
row_sequence,timestamp_ms,ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps
```

- Leave the board still for several seconds. The acceleration vector's magnitude
  should be approximately **1 g** because it includes gravity. Individual axis
  values depend on orientation. Gyroscope values should be near zero, with some
  bias and noise.
- Tilt and rotate the board slowly, then return it to rest. Check that values
  respond and settle. Record which physical baton movement corresponds to each
  positive/negative board axis once its mounting orientation is known.
- Capture 5–10 seconds each of rest, movement, and return to rest, along with
  the installed core/library versions. These recordings guide the BLE contract
  and motion mapper; they are not clinical calibration thresholds.

The sensor is configured for +/- 4 g, +/- 500 degrees/second, and a 104 Hz sensor
output data rate. USB logging is slower and reads the six axes independently;
it does not guarantee a synchronized frame or expose sensor-bus errors after
initialization. Use this sketch to check basic operation, then add validated
frame acquisition and error handling for production streaming.
[Library APIs and units](https://github.com/Seeed-Studio/Seeed_Arduino_LSM6DS3/blob/v2.0.7/LSM6DS3.cpp).

`row_sequence` counts printed diagnostic rows. `timestamp_ms` is board uptime
from `millis()`; it wraps after about 49.7 days. Both restart when the board
reboots. These fields are not yet the app's stream/session identifiers.
When converting to the plan's SI units, multiply acceleration in g by 9.80665
and angular velocity in degrees/second by pi/180. Gyroscope readings are angular
velocity, not orientation angles.

## If upload or readings fail

- If Verify reports `Adafruit_TinyUSB.h: No such file or directory`, confirm
  the selected board comes from **Seeed nRF52 Boards** (non-mbed), then install
  **Adafruit TinyUSB Library** through Library Manager as described above and
  Verify again. Keep the include in this sketch.
- If it instead reports `TinyUSB Arduino Library does not support your core
  yet`, the library was found but its core-selection check failed. In **Tools >
  Board**, select **Seeed nRF52 Boards > Seeed XIAO nRF52840 Sense**; the similarly
  named board under **Seeed nRF52 mbed-enabled Boards** uses a different core.
  Verify again. If the error remains, capture the full board package name and
  version and the beginning of verbose compilation output before changing
  library versions. The intended non-mbed core defines `ARDUINO_NRF52_ADAFRUIT`,
  which TinyUSB uses to select its nRF52 support.
  [Core compiler flags](https://github.com/Seeed-Studio/Adafruit_nRF52_Arduino/blob/1.1.13/platform.txt),
  [TinyUSB core selection](https://github.com/adafruit/Adafruit_TinyUSB_Arduino/blob/master/src/tusb_config.h).
- If no port appears, check the data cable and try another USB port.
- If upload no longer finds the application port, Seeed documents pressing
  reset twice quickly to enter the bootloader. Select the new port and retry.
  [Seeed bootloader recovery](https://wiki.seeedstudio.com/XIAO_BLE/).
- An IMU initialization error should prompt a check of the **Sense** board
  selection, non-mbed core, and Seeed IMU library. No external IMU wiring is
  required for this check.

## Validation status and app connection

The user uploaded the USB sketch and provided live readings. This confirms
basic sensor operation; the board was on the user's lap, so these readings do
not establish a stationary gyroscope offset or an exercise calibration.

Upload the separate [BLE sketch and run the phone test](ble-motion.md) to use the
board with the app. The Flutter demo includes the matching packet decoder,
Bluetooth transport, movement mapping, instruments, and song playback. Disconnect
LightBlue before using **Connect baton** in the app; the board accepts one
connection at a time. Follow the [demo guide](../docs/demo-guide.md) for gameplay
and the remaining physical-device checks. Patient calibration and measured
gesture-to-audio latency remain unfinished.
