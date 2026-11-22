#include "telemetry_protocol.h"
#include <math.h>
namespace protocol {
static void word(uint8_t *p, uint16_t n) {
  p[0] = n & 255;
  p[1] = n >> 8;
}
static void dword(uint8_t *p, uint32_t n) {
  word(p, n & 65535);
  word(p + 2, n >> 16);
}
static void header(uint8_t *p, uint8_t flags, uint16_t seq, uint32_t t) {
  p[0] = 1;
  p[1] = flags;
  word(p + 2, seq);
  dword(p + 4, t);
}
static uint16_t quant(float value, float scale) {
  return static_cast<uint16_t>(static_cast<int16_t>(
      lroundf(fminf(32767, fmaxf(-32768, value * scale)))));
}
Raw encodeRaw(uint8_t flags, uint16_t seq, uint32_t t, const float *a,
              const float *g) {
  Raw p{};
  header(p.data(), flags, seq, t);
  for (int i = 0; i < 3; i++) {
    word(p.data() + 8 + i * 2, quant(a[i], 1000));
    word(p.data() + 14 + i * 2, quant(g[i], 100));
  }
  return p;
}
Orientation encodeOrientation(uint8_t flags, uint16_t seq, uint32_t t,
                              const float *q) {
  Orientation p{};
  header(p.data(), flags, seq, t);
  for (int i = 0; i < 4; i++)
    word(p.data() + 8 + i * 2, quant(q[i], 16384));
  return p;
}
StatusPacket encodeStatus(Health health, uint8_t activity, uint8_t intensity,
                          uint32_t t, uint16_t io, uint16_t invalid,
                          uint16_t timing, uint16_t dropped, uint16_t eventId,
                          int16_t temp) {
  StatusPacket p{};
  p[0] = 1;
  p[1] = health;
  p[2] = activity;
  p[3] = intensity;
  dword(p.data() + 4, t);
  word(p.data() + 8, io);
  word(p.data() + 10, invalid);
  word(p.data() + 12, timing);
  word(p.data() + 14, dropped);
  word(p.data() + 16, eventId);
  word(p.data() + 18, temp);
  return p;
}
} // namespace protocol
