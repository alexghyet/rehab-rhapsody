# Send motion readings over Bluetooth

This sketch streams the XIAO's motion readings to the Flutter app. Use LightBlue
first to check delivery independently, then disconnect LightBlue and follow the
[app demo guide](../docs/demo-guide.md) to play music with the baton.

## Upload the Bluetooth sketch

1. In Arduino IDE, open [ble_motion/ble_motion.ino](ble_motion/ble_motion.ino)
   from this repository. Open it as its own sketch, not an additional tab inside
   `imu_check` (both sketches define `setup()` and `loop()`).
2. Keep **Tools > Board > Seeed nRF52 Boards > Seeed XIAO nRF52840 Sense** and
   the board's COM port selected. Keep the installed IMU/TinyUSB libraries.
   The BLE library, **Adafruit Bluefruit**, is included in the board package;
   this sketch does not use ArduinoBLE.
   [Seeed's non-mbed BLE guide](https://wiki.seeedstudio.com/XIAO-BLE-Sense-Bluetooth_Usage/).
3. Click **Verify**, then **Upload**. This replaces the USB diagnostic on the
   board. Keep USB connected for power during this test.
4. Optional: open Serial Monitor at **115200 baud**. It should report
   `Advertising: Rehab Rhapsody`, then connection/subscription status. It no
   longer prints CSV motion rows. BLE runs with Serial Monitor closed.

## Check it from your iPhone

1. Install [LightBlue by Punch Through](https://apps.apple.com/us/app/lightblue/id557428110).
   It can scan for BLE peripherals and subscribe to characteristic notifications.
2. Turn on Bluetooth, open LightBlue, and allow Bluetooth access when requested.
   Scan inside LightBlue and connect to **Rehab Rhapsody**. Use the BLE app for
   discovery rather than the phone's Bluetooth pairing list.
3. Open the service with UUID **b8141000-8c3f-4b0b-9a7c-1a16adcc7a21**.
4. Open its **Motion v1** characteristic, UUID
   **b8141001-8c3f-4b0b-9a7c-1a16adcc7a21**, and enable notifications (the app
   may label this Subscribe or Listen for notifications).
5. Expect repeated **20-byte binary/hex** values. Leave the board still, then
   tilt it slowly. The header/sequence/time bytes change even at rest; the
   sensor bytes should change with motion. These are binary packets, not text.
6. Disconnect, rescan, reconnect, and subscribe again. Updates should resume.
   Disable notifications or disconnect in LightBlue to stop receiving updates.

The success check is notifications arriving and responding to movement after
reconnection. This does not yet validate calibrated gestures, audio, latency,
or the Flutter app's connection indicator.

If it does not appear, check Serial Monitor for startup errors, phone Bluetooth
permission, and power. Only one phone can connect at a time. If another BLE app
is connected, disconnect there before scanning again. If connected without
updates, enable notifications on the motion characteristic.

## Motion protocol v1

This is a project-specific experimental GATT service, with an open connection
and no pairing requirement. It sends only raw motion samples. All multi-byte
integers are **little-endian**; axis readings are signed 16-bit two's-complement.
Each notification contains exactly one 20-byte packet, with no fragmentation
or MTU negotiation required for this payload size.

| Offset | Bytes | Field | Meaning |
| --- | --- | --- | --- |
| 0 | 1 | version | Always 1 |
| 1 | 1 | reserved | Always 0; reject other values for v1 |
| 2 | 2 | sequence | Unsigned 16-bit acquisition-attempt counter |
| 4 | 4 | timestampUs | Unsigned 32-bit board uptime, captured before acquisition |
| 8 | 6 | acceleration XYZ | Three raw signed 16-bit accelerometer readings |
| 14 | 6 | angular velocity XYZ | Three raw signed 16-bit gyroscope readings |

Sensor configuration is fixed in v1: **±4 g**, **±500 degrees/second**, and
**104 Hz** output data rate on both sensors. For these settings:

- Acceleration in g = raw value × 0.000122; in m/s² = raw × 0.000122 × 9.80665.
- Angular velocity in degrees/second = raw value × 0.0175; in rad/s = raw ×
  0.0175 × pi/180.

These scale factors match Seeed's
[LSM6DS3 driver](https://github.com/Seeed-Studio/Seeed_Arduino_LSM6DS3/blob/v2.0.7/LSM6DS3.cpp).
Do not change sensor ranges without also changing the version/decoder contract.
Values include gravity, bias, noise, and possible physical sensor saturation;
there is no calibration or filtering beyond the sensor's configured behavior.

The send loop targets **50 Hz**, independently of the sensor ODR. Actual arrival
rate depends on phone connection scheduling and radio conditions. Failed reads,
missing fresh data, and failed notifications are dropped, with no retry queue.
The firmware checks both data-ready bits, enables block-data update, and checks
the length of the 12-byte sensor read. This is polled acquisition, not a FIFO
or a promise that both sensors share an exact sampling instant.

The sequence wraps modulo 65536 and resets on board reboot. It counts attempts
only while connected and subscribed, continuing across reconnections if the
board stays powered. `timestampUs` wraps modulo 2^32 (about 71.6 minutes) and
resets on reboot. No persistent device/session ID is sent in v1.

The Flutter receiver starts a fresh stream generation on each connection and
notification subscription, rejects invalid packet sizes/versions/reserved bytes,
and ignores callbacks from older generations. Its
[stream guard](../lib/features/motion/motion_stream_guard.dart) computes sequence
differences modulo 65536: zero is a duplicate; 1..32767 is forward;
32768..65535 is stale or ambiguous. Timestamp deltas use modulo 2^32. A silence
longer than two seconds expires the stream and pauses playback; reconnect to
start a fresh stream instead of interpreting ambiguous counter differences.

## Validation

The sketch compiles successfully with the installed **Seeed nRF52 Boards
1.1.13**, **Seeed Arduino LSM6DS3 2.0.7**, and Arduino IDE's bundled CLI, targeting
`Seeeduino:nrf52:xiaonRF52840Sense`. Build output reports 151488 bytes of program
storage and 19452 bytes of global/static RAM. No upload was performed by the
assistant.

The user confirmed receiving values in LightBlue and supplied a screenshot.
The five [captured packets](captures/lightblue-motion-v1.json) each decode as
20-byte v1 packets with reserved byte zero, consecutive sequences 907–911,
and increasing device timestamps. The latest packet decodes to acceleration
(-0.005124, 0.130418, 1.034926) g and angular velocity
(2.135, -4.34, 0.14) degrees/second. Acceleration magnitude is about 1.043 g.
This confirms basic phone discovery and delivery of decodable motion samples.

Device timestamp differences in this short capture are 59570–60547 microseconds,
or about **16.7 samples/second**, below the 50 Hz loop target. Investigate the
acquisition/notification timing before claiming a 50 Hz stream. The screenshot
does not establish stationary bias, deliberate movement response, reconnection,
sustained packet loss, or gesture-to-audio latency; those checks remain pending.
