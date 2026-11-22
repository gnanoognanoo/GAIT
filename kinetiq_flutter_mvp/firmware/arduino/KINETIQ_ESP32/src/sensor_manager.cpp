#include "sensor_manager.h"
#include "configuration.h"
#include <Wire.h>

namespace {
constexpr auto accelRange =
    config::accelerometerRange == 2   ? MPU6050_RANGE_2_G
    : config::accelerometerRange == 4 ? MPU6050_RANGE_4_G
    : config::accelerometerRange == 8 ? MPU6050_RANGE_8_G
                                      : MPU6050_RANGE_16_G;
constexpr auto gyroRange = config::gyroRange == 250    ? MPU6050_RANGE_250_DEG
                           : config::gyroRange == 500  ? MPU6050_RANGE_500_DEG
                           : config::gyroRange == 1000 ? MPU6050_RANGE_1000_DEG
                                                       : MPU6050_RANGE_2000_DEG;
constexpr auto bandwidth = config::bandwidthHz == 44   ? MPU6050_BAND_44_HZ
                           : config::bandwidthHz == 10 ? MPU6050_BAND_10_HZ
                                                       : MPU6050_BAND_21_HZ;
static_assert(config::accelerometerRange == 2 ||
                  config::accelerometerRange == 4 ||
                  config::accelerometerRange == 8 ||
                  config::accelerometerRange == 16,
              "Unsupported accelerometer range");
static_assert(config::gyroRange == 250 || config::gyroRange == 500 ||
                  config::gyroRange == 1000 || config::gyroRange == 2000,
              "Unsupported gyro range");
static_assert(config::bandwidthHz == 44 || config::bandwidthHz == 21 ||
                  config::bandwidthHz == 10,
              "Unsupported bandwidth");
constexpr int magnitude(int n) { return n < 0 ? -n : n; }
constexpr int x = config::mountingAxes[0], y = config::mountingAxes[1],
              z = config::mountingAxes[2];
static_assert(magnitude(x) * magnitude(y) * magnitude(z) == 6 &&
                  magnitude(x) + magnitude(y) + magnitude(z) == 6 &&
                  ((x * y * z > 0) == ((magnitude(x) - magnitude(y)) *
                                           (magnitude(y) - magnitude(z)) *
                                           (magnitude(z) - magnitude(x)) >
                                       0)),
              "Mounting map must be a right-handed signed permutation");
constexpr float accelScale = 32768.f / config::accelerometerRange;
constexpr float gyroScale = config::gyroRange == 250    ? 131.f
                            : config::gyroRange == 500  ? 65.5f
                            : config::gyroRange == 1000 ? 32.8f
                                                        : 16.4f;
Adafruit_I2CDevice bus(config::address, &Wire);
int16_t signedWord(const uint8_t *data) {
  return static_cast<int16_t>((uint16_t(data[0]) << 8) | data[1]);
}
} // namespace
bool Sensor::begin() {
  if (!Wire.begin(config::sda, config::scl))
    return false;
  Wire.setTimeOut(10);
  if (!driver.begin(config::address, &Wire) || !bus.begin())
    return false;
  static_assert(1000 % config::sampleHz == 0 && config::telemetryHz > 0 &&
                    config::sampleHz % config::telemetryHz == 0,
                "Choose integral rate divisors");
  driver.setAccelerometerRange(accelRange);
  driver.setGyroRange(gyroRange);
  driver.setFilterBandwidth(bandwidth);
  driver.setSampleRateDivisor(1000 / config::sampleHz - 1);
  return driver.getAccelerometerRange() == accelRange &&
         driver.getGyroRange() == gyroRange &&
         driver.getFilterBandwidth() == bandwidth;
}
bool Sensor::read(Sample &s) {
  // MPU6050 2.2.6 getEvent() discards BusIO's read outcome.
  uint8_t reg = MPU6050_ACCEL_OUT, bytes[14];
  if (!bus.write_then_read(&reg, 1, bytes, sizeof(bytes)))
    return false;
  s.clipped = false;
  for (int i = 0; i < 3; i++) {
    const int map = config::mountingAxes[i], axis = abs(map) - 1;
    const int16_t a = signedWord(bytes + axis * 2),
                  g = signedWord(bytes + 8 + axis * 2);
    s.clipped |= abs(int(a)) >= 32700 || abs(int(g)) >= 32700;
    s.a.array[i] = (map > 0 ? 1 : -1) * a / accelScale;
    s.gyro.array[i] = (map > 0 ? 1 : -1) * g / gyroScale;
  }
  s.temperature = signedWord(bytes + 6) / 340.f + 36.53f;
  return true;
}
