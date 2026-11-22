#include "motion_analyzer.h"
#include "sensor_calibration.h"
#include "telemetry_protocol.h"
#include <assert.h>
#include <stdio.h>

int main() {
  Calibration cal;
  FusionVector still = {{0, 0, 1}}, noise = {{.6f, -.3f, .15f}};
  FusionVector movement = {{30, 0, 0}};
  for (int i = 0; i < 299; i++)
    assert(!cal.update(still, noise));
  assert(!cal.update(still, movement));
  for (int i = 0; i < 299; i++)
    assert(!cal.update(still, noise));
  assert(cal.update(still, noise));
  assert(fabsf(cal.bias().array[0] - .6f) < .001f);
  Attitude attitude;
  attitude.reset(cal.bias());
  for (int i = 0; i < 500; i++)
    assert(attitude.update(still, noise, .01f));
  assert(!attitude.recovery);
  assert(fabsf(attitude.quaternion.array[0] - 1) < .001f);
  assert(!attitude.update(still, noise, .1f));
  for (int i = 0; i < 100; i++) {
    const float angle = i * .01f * 3.14159265359f / 2;
    FusionVector tilted = {{0, sinf(angle), cosf(angle)}};
    FusionVector rate = {{90.6f, -.3f, .15f}};
    assert(attitude.update(tilted, rate, .01f));
  }
  assert(fabsf(attitude.euler.angle.roll - 90) < 3);
  assert(fabsf(FusionQuaternionNorm(attitude.quaternion) - 1) < .0001f);
  MotionAnalyzer motion;
  FusionVector strong = {{1, 0, 0}};
  for (int i = 0; i < 100; i++)
    motion.update(strong, movement, .01f, i * 10);
  assert(motion.activity == 3 && motion.eventId > 0);
  for (int i = 0; i < 160; i++)
    motion.update(FUSION_VECTOR_ZERO, FUSION_VECTOR_ZERO, .01f, 1000 + i * 10);
  assert(motion.activity == 0);
  const float a[] = {-1, 0, 1}, g[] = {12.34f, 500, -500}, q[] = {1, 0, 0, 0};
  auto raw = protocol::encodeRaw(3, 65535, 0x12345678, a, g);
  const protocol::Raw expected = {1,    3,    255,  255, 0x78, 0x56, 0x34,
                                  0x12, 0x18, 0xfc, 0,   0,    0xe8, 3,
                                  0xd2, 4,    255,  127, 0,    128};
  assert(raw == expected);
  auto orientation = protocol::encodeOrientation(3, 1, 0, q);
  assert(orientation[8] == 0 && orientation[9] == 64);
  auto status = protocol::encodeStatus(protocol::Ready, 3, 99, 24, 1, 2, 3, 4,
                                       5, INT16_MIN);
  assert(status[3] == 99 && status[16] == 5 && status[19] == 128);
  puts("Calibration, measured timing, controlled rotation, motion and protocol "
       "fixtures passed");
}
