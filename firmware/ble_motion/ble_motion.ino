// XIAO nRF52840 Sense, non-mbed Seeed nRF52 Boards 1.1.13.
// Upload this instead of imu_check; see ../ble-motion.md for the phone test.
#include <Arduino.h>
#include <Adafruit_TinyUSB.h>
#include <LSM6DS3.h>
#include <Wire.h>
#include <bluefruit.h>

constexpr uint8_t kImuAddress = 0x6A;
constexpr uint32_t kSamplePeriodUs = 20000; // Target 50 notifications/second.
constexpr uint8_t kPacketLength = 20;
const char kServiceUuid[] = "b8141000-8c3f-4b0b-9a7c-1a16adcc7a21";
const char kMotionUuid[] = "b8141001-8c3f-4b0b-9a7c-1a16adcc7a21";

LSM6DS3 imu(I2C_MODE, kImuAddress);
BLEService motionService(kServiceUuid);
BLECharacteristic motionCharacteristic(kMotionUuid);

bool ready = false;
const char* startupError = "Startup failed";
uint16_t sequence = 0;
uint32_t lastSampleUs = 0;
uint32_t lastStatusMs = 0;

// Use the Sense board's internal bus, initialized/powered by imu.begin().
// Check the transfer length as well as the I2C address phase.
bool readSensorBytes(uint8_t address, uint8_t* output, uint8_t length) {
  Wire1.beginTransmission(kImuAddress);
  Wire1.write(address);
  if (Wire1.endTransmission(false) != 0) return false;
  if (Wire1.requestFrom(kImuAddress, length) != length) {
    while (Wire1.available()) Wire1.read();
    return false;
  }
  for (uint8_t i = 0; i < length; ++i) output[i] = Wire1.read();
  return true;
}

void write16(uint8_t* output, uint16_t value) {
  output[0] = static_cast<uint8_t>(value);
  output[1] = static_cast<uint8_t>(value >> 8);
}

void write32(uint8_t* output, uint32_t value) {
  for (uint8_t i = 0; i < 4; ++i) output[i] = value >> (8 * i);
}

void setup() {
  Serial.begin(115200); // BLE also works with Serial Monitor closed.
  imu.settings.accelRange = 4;
  imu.settings.gyroRange = 500;
  imu.settings.accelSampleRate = 104;
  imu.settings.gyroSampleRate = 104;
  startupError = "IMU initialization failed";
  if (imu.begin() != IMU_SUCCESS) return;

  // CTRL3_C: enable block-data update and address auto-increment.
  if (imu.writeRegister(LSM6DS3_ACC_GYRO_CTRL3_C, 0x44) != IMU_SUCCESS) return;
  delay(200);

  startupError = "BLE initialization failed";
  if (!Bluefruit.begin(1, 0)) return;
  Bluefruit.setName("Rehab Rhapsody");
  Bluefruit.Periph.setConnInterval(12, 24); // Request 15-30 ms; phone decides.
  if (motionService.begin() != ERROR_NONE) return;
  motionCharacteristic.setProperties(CHR_PROPS_NOTIFY);
  motionCharacteristic.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  motionCharacteristic.setFixedLen(kPacketLength);
  motionCharacteristic.setUserDescriptor("Motion v1");
  if (motionCharacteristic.begin() != ERROR_NONE) return;

  startupError = "BLE advertising failed";
  if (!Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE)
      || !Bluefruit.Advertising.addService(motionService)
      || !Bluefruit.ScanResponse.addName()) return;
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(32, 244);
  Bluefruit.Advertising.setFastTimeout(30);
  ready = Bluefruit.Advertising.start(0);
}

void loop() {
  const uint32_t nowMs = millis();
  if (nowMs - lastStatusMs >= 1000) {
    lastStatusMs = nowMs;
    if (Serial) {
      if (!ready) Serial.println(startupError);
      else if (!Bluefruit.connected()) Serial.println("Advertising: Rehab Rhapsody");
      else if (!motionCharacteristic.notifyEnabled()) Serial.println("Connected: enable motion notifications on phone");
      else Serial.println("Motion notifications enabled");
    }
  }

  if (!ready || !Bluefruit.connected() || !motionCharacteristic.notifyEnabled()) {
    delay(10);
    return;
  }

  const uint32_t nowUs = micros();
  if (static_cast<uint32_t>(nowUs - lastSampleUs) < kSamplePeriodUs) {
    delay(1);
    return;
  }
  lastSampleUs = nowUs; // Drop missed ticks; never queue a catch-up burst.
  const uint16_t sampleSequence = sequence++;

  uint8_t sensorStatus = 0;
  uint8_t sensorBytes[12]; // Gyroscope XYZ, then acceleration XYZ, little-endian.
  if (!readSensorBytes(LSM6DS3_ACC_GYRO_STATUS_REG, &sensorStatus, 1)
      || (sensorStatus & 0x03) != 0x03
      || !readSensorBytes(LSM6DS3_ACC_GYRO_OUTX_L_G, sensorBytes, sizeof(sensorBytes))) {
    // No fabricated/stale frame on a bus error or when no new sample is ready.
    // Sequence gaps also cover these dropped acquisition attempts.
    return;
  }

  uint8_t packet[kPacketLength] = {1, 0}; // Version 1, reserved byte 0.
  write16(packet + 2, sampleSequence);
  write32(packet + 4, nowUs);
  memcpy(packet + 8, sensorBytes + 6, 6); // Raw acceleration XYZ.
  memcpy(packet + 14, sensorBytes, 6);    // Raw angular velocity XYZ.
  // Failed notifications are dropped, never replayed on a later connection.
  motionCharacteristic.notify(packet, sizeof(packet));
}
