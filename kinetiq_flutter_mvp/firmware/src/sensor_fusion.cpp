#include "sensor_fusion.h"
#include "configuration.h"
void Attitude::reset(FusionVector offset) {
  FusionBiasInitialise(&bias);
  const FusionBiasSettings biasSettings = {float(config::sampleHz), 1.0f, 4.0f};
  FusionBiasSetSettings(&bias, &biasSettings);
  FusionBiasSetOffset(&bias, offset);
  FusionAhrsInitialise(&ahrs);
  const FusionAhrsSettings settings = {float(config::sampleHz),
                                       FusionConventionNwu,
                                       .5f,
                                       config::gyroRange,
                                       10.f,
                                       0.f,
                                       5.f};
  FusionAhrsSetSettings(&ahrs, &settings);
}
bool Attitude::update(FusionVector a, FusionVector g, float dt) {
  if (!isfinite(dt) || dt <= 0 || dt > .05f)
    return false;
  gyro = FusionBiasUpdate(&bias, g);
  FusionAhrsSetSamplePeriod(&ahrs, dt);
  FusionAhrsUpdateNoMagnetometer(&ahrs, gyro, a);
  quaternion = FusionAhrsGetQuaternion(&ahrs);
  const float norm = FusionQuaternionNorm(quaternion);
  if (!isfinite(norm) || fabsf(norm - 1) > .03f)
    return false;
  for (float &part : quaternion.array)
    part /= norm;
  euler = FusionQuaternionToEuler(quaternion);
  linear = FusionAhrsGetLinearAcceleration(&ahrs);
  const auto flags = FusionAhrsGetFlags(&ahrs);
  rejection = FusionAhrsGetInternalStates(&ahrs).accelerometerIgnored;
  recovery =
      flags.startup || flags.accelerationRecovery || flags.overrangeRecovery;
  overrange = flags.overrangeRecovery;
  return true;
}
