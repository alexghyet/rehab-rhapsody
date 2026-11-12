// USB diagnostic for the Seeed Studio XIAO nRF52840 Sense.
// Use the non-mbed "Seeed nRF52 Boards" core; see ../README.md.
#include <Arduino.h>
#include <Adafruit_TinyUSB.h>
#include <LSM6DS3.h>
#include <Wire.h>

LSM6DS3 imu(I2C_MODE, 0x6A);

bool imuReady = false;
bool serialWasOpen = false;
uint32_t rowSequence = 0;

void setup() {
  Serial.begin(115200);

  // Sensor configuration for diagnostics, not an exercise calibration.
  imu.settings.accelRange = 4;       // +/- 4 g
  imu.settings.gyroRange = 500;      // +/- 500 degrees/second
  imu.settings.accelSampleRate = 104; // Sensor output data rate in Hz
  imu.settings.gyroSampleRate = 104;
  // The Seeed library handles the onboard IMU power and I2C bus.
  imuReady = imu.begin() == IMU_SUCCESS;
  delay(200);
}

void loop() {
  // Never wait indefinitely in setup for a USB Serial Monitor to be opened.
  if (!Serial) {
    serialWasOpen = false;
    delay(100);
    return;
  }

  if (!imuReady) {
    Serial.println("ERROR: IMU initialization failed; check board/core/library.");
    delay(1000);
    return;
  }

  if (!serialWasOpen) {
    Serial.println("# Rehab Rhapsody IMU diagnostic; g and degrees/second");
    Serial.println("row_sequence,timestamp_ms,ax_g,ay_g,az_g,gx_dps,gy_dps,gz_dps");
    serialWasOpen = true;
  }

  // These are independent diagnostic reads, not an atomic sensor/FIFO frame.
  const uint32_t timestampMs = millis();
  const float ax = imu.readFloatAccelX();
  const float ay = imu.readFloatAccelY();
  const float az = imu.readFloatAccelZ();
  const float gx = imu.readFloatGyroX();
  const float gy = imu.readFloatGyroY();
  const float gz = imu.readFloatGyroZ();

  Serial.print(rowSequence++);
  Serial.print(',');
  Serial.print(timestampMs);
  Serial.print(',');
  Serial.print(ax, 4);
  Serial.print(',');
  Serial.print(ay, 4);
  Serial.print(',');
  Serial.print(az, 4);
  Serial.print(',');
  Serial.print(gx, 4);
  Serial.print(',');
  Serial.print(gy, 4);
  Serial.print(',');
  Serial.println(gz, 4);

  // Approximately 10 diagnostic rows/second; this is not the sensor ODR.
  delay(100);
}
