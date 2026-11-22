#include "sensor_calibration.h"
void Calibration::reset() {
  count = 0;
  mean = {};
  squaredDeviation = {};
}
bool Calibration::update(FusionVector acceleration, FusionVector angularRate) {
  if (fabsf(FusionVectorNorm(acceleration) - 1) > .08f ||
      FusionVectorNorm(angularRate) > 4) {
    reset();
    return false;
  }
  ++count;
  for (int i = 0; i < 3; i++) {
    const float delta = angularRate.array[i] - mean.array[i];
    mean.array[i] += delta / count;
    squaredDeviation.array[i] += delta * (angularRate.array[i] - mean.array[i]);
  }
  if (count < config::sampleHz * 3)
    return false;
  if (FusionVectorNorm(squaredDeviation) / count > .25f) {
    reset();
    return false;
  }
  return true;
}
