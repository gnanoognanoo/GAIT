#include "diagnostics.h"
#include <Arduino.h>
void Diagnostics::print(protocol::Health health, uint32_t uptime) {
  Serial.printf("{\"uptime_ms\":%lu,\"health\":%u,\"samples_window\":%u,\"tx_"
                "pairs_window\":%u,"
                "\"i2c_errors\":%u,\"invalid\":%u,\"timing_errors\":%u,\"tx_"
                "failures\":%u}\n",
                static_cast<unsigned long>(uptime), unsigned(health), samples,
                frames, io, invalid, timing, dropped);
  samples = frames = 0;
}
