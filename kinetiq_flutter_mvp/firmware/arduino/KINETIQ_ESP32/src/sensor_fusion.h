#pragma once
extern "C" {
#include "fusion/Fusion.h"
}
class Attitude {
public:
  void reset(FusionVector offset);
  bool update(FusionVector a, FusionVector g, float interval);
  FusionQuaternion quaternion{};
  FusionEuler euler{};
  FusionVector linear{}, gyro{};
  bool rejection = false, recovery = true, overrange = false;

private:
  FusionBias bias;
  FusionAhrs ahrs;
};
