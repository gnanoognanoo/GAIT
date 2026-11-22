#pragma once
#include "configuration.h"
extern "C" {
#include "fusion/Fusion.h"
}
class Calibration {
public:
  void reset();
  bool update(FusionVector acceleration, FusionVector angularRate);
  FusionVector bias() const { return mean; }

private:
  unsigned count = 0;
  FusionVector mean{}, squaredDeviation{};
};
