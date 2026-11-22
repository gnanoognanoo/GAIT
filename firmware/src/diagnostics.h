#pragma once
#include "telemetry_protocol.h"
struct Diagnostics {
  uint16_t io = 0, invalid = 0, timing = 0, dropped = 0;
  unsigned samples = 0, frames = 0;
  void print(protocol::Health health, uint32_t uptime);
};
