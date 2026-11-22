#pragma once
#include <Adafruit_MPU6050.h>
extern "C" {
#include "fusion/Fusion.h"
}
struct Sample {
  FusionVector a, gyro;
  float temperature;
  bool clipped;
};
class Sensor {
public:
  bool begin();
  bool read(Sample &sample);

private:
  Adafruit_MPU6050 driver;
};
