#pragma once
#include "sensor_fusion.h"
#include <stdint.h>
class MotionAnalyzer {
public:
  void reset();
  void update(FusionVector linear, FusionVector gyro, float dt, uint32_t stamp);
  unsigned activity = 0;
  float intensity = 0;
  uint16_t eventId = 0;
  uint32_t eventTime = 0;

private:
  bool emitted = false;
};
