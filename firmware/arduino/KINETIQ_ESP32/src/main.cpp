#include "ble_manager.h"
#include "configuration.h"
#include "diagnostics.h"
#include "motion_analyzer.h"
#include "sensor_calibration.h"
#include "sensor_manager.h"
#include <Arduino.h>

namespace {
Sensor sensor;
Calibration calibration;
Attitude attitude;
MotionAnalyzer motion;
Diagnostics diag;
bool available = false, calibrated = false, streaming = false;
protocol::Health health = protocol::Missing;
uint32_t nextSample, lastSample, retryAt, statusAt, serialAt;
uint16_t sequence;
int16_t temperature = INT16_MIN;
unsigned samplesToPublish = 0;

void beginCalibration() {
  calibrated = false;
  calibration.reset();
  motion.reset();
  health = available ? protocol::StationaryWindow : protocol::Missing;
}
void publishStatus(uint32_t now) {
  sendStatus(protocol::encodeStatus(
      health, motion.activity, lroundf(motion.intensity * 100), now, diag.io,
      diag.invalid, diag.timing, diag.dropped, motion.eventId, temperature));
}
void acquire(uint32_t now, float dt) {
  Sample s{};
  if (!sensor.read(s)) {
    ++diag.io;
    available = false;
    beginCalibration();
    health = protocol::IoError;
    retryAt = now + 2000;
    temperature = INT16_MIN;
    return;
  }
  ++diag.samples;
  temperature = lroundf(s.temperature * 100);
  if (s.clipped) {
    ++diag.invalid;
    health = protocol::Clipped;
    motion.reset();
    if (calibrated)
      attitude.reset(calibration.bias());
    else
      calibration.reset();
    return;
  }
  if (!calibrated) {
    if (!calibration.update(s.a, s.gyro)) {
      health = protocol::StationaryWindow;
      return;
    }
    attitude.reset(calibration.bias());
    calibrated = true;
  }
  if (!attitude.update(s.a, s.gyro, dt)) {
    ++diag.invalid;
    health = protocol::Timing;
    attitude.reset(calibration.bias());
    motion.reset();
    return;
  }
  health = protocol::Ready;
  const unsigned previous = motion.activity;
  if (!attitude.recovery)
    motion.update(attitude.linear, attitude.gyro, dt, now);
  else
    motion.reset();
  if (motion.activity != previous)
    publishStatus(now);
  if (++samplesToPublish < config::sampleHz / config::telemetryHz)
    return;
  samplesToPublish = 0;
  if (!streaming || !streamingLink())
    return;
  uint8_t flags = protocol::Healthy | protocol::Calibrated;
  if (motion.activity > 0)
    flags |= protocol::Movement;
  if (motion.activity == 3)
    flags |= protocol::High;
  if (attitude.rejection)
    flags |= protocol::Rejection;
  if (attitude.recovery)
    flags |= protocol::Recovery;
  if (attitude.overrange ||
      fmaxf(fabsf(s.gyro.array[0]),
            fmaxf(fabsf(s.gyro.array[1]), fabsf(s.gyro.array[2]))) > 327.67f)
    flags |= protocol::Overrange;
  const uint32_t stamp = now;
  const auto raw =
      protocol::encodeRaw(flags, sequence, stamp, s.a.array, s.gyro.array);
  const auto orientation = protocol::encodeOrientation(
      flags, sequence++, stamp, attitude.quaternion.array);
  if (sendMotion(raw, orientation))
    ++diag.frames;
  else
    ++diag.dropped;
}
} // namespace
void setup() {
  Serial.begin(115200);
  beginBle();
  nextSample = lastSample = micros();
}
void loop() {
  const uint32_t now = millis();
  switch (nextCommand()) {
  case protocol::Start:
    streaming = true;
    publishStatus(now);
    break;
  case protocol::Stop:
    streaming = false;
    publishStatus(now);
    break;
  case protocol::Calibrate:
    beginCalibration();
    publishStatus(now);
    break;
  case protocol::Status:
    publishStatus(now);
    break;
  default:
    break;
  }
  if (!streamingLink())
    streaming = false;
  if (!available && int32_t(now - retryAt) >= 0) {
    available = sensor.begin();
    if (available)
      beginCalibration();
    else {
      health = protocol::Missing;
      retryAt = now + 2000;
      ++diag.io;
    }
    nextSample = lastSample = micros();
  }
  const uint32_t tick = micros();
  if (available && int32_t(tick - nextSample) >= 0) {
    const uint32_t elapsed = tick - lastSample;
    lastSample = tick;
    nextSample += config::sampleUs;
    if (int32_t(tick - nextSample) >= 0) {
      ++diag.timing;
      nextSample = tick + config::sampleUs;
    }
    if (elapsed)
      acquire(now, elapsed * 1e-6f);
  }
  if (int32_t(now - statusAt) >= 0) {
    statusAt = now + 200;
    publishStatus(now);
  }
  if (int32_t(now - serialAt) >= 0) {
    serialAt = now + 1000;
    diag.print(health, now);
  }
  yield();
}
