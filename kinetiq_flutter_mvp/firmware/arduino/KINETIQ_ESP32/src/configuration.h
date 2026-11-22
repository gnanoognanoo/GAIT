#pragma once
#include <stdint.h>
namespace config {
constexpr int sda = 21, scl = 22;
constexpr uint8_t address = 0x68;
constexpr unsigned sampleHz = 100, telemetryHz = 50;
constexpr uint32_t sampleUs = 1000000 / sampleHz;
constexpr float accelerometerRange = 8, gyroRange = 500;
constexpr int bandwidthHz = 21;
// Right-handed signed permutation of the board axes. Positive values preserve
// sign.
constexpr int mountingAxes[] = {1, 2, 3};
constexpr float activityThresholds[] = {0.07f, 0.22f, 0.50f};
constexpr uint32_t eventCooldownMs = 800;
} // namespace config
