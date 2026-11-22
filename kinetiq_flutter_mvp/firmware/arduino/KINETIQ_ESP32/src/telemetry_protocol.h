#pragma once
#include <array>
#include <stdint.h>
namespace protocol {
constexpr char service[] = "8f6d0001-7a1b-4c2e-9f52-2a6e4b1c0001";
constexpr char raw[] = "8f6d0002-7a1b-4c2e-9f52-2a6e4b1c0001";
constexpr char orientation[] = "8f6d0003-7a1b-4c2e-9f52-2a6e4b1c0001";
constexpr char control[] = "8f6d0004-7a1b-4c2e-9f52-2a6e4b1c0001";
constexpr char status[] = "8f6d0005-7a1b-4c2e-9f52-2a6e4b1c0001";
enum Flags : uint8_t {
  Healthy = 1,
  Calibrated = 2,
  Movement = 4,
  High = 8,
  Rejection = 16,
  Overrange = 32,
  Recovery = 64
};
enum Command : uint8_t { Start = 1, Stop = 2, Calibrate = 3, Status = 4 };
enum Health : uint8_t {
  Ready,
  Missing,
  StationaryWindow,
  IoError,
  Clipped,
  Timing
};
using Raw = std::array<uint8_t, 20>;
using Orientation = std::array<uint8_t, 16>;
using StatusPacket = std::array<uint8_t, 20>;
Raw encodeRaw(uint8_t flags, uint16_t seq, uint32_t time, const float *a,
              const float *g);
Orientation encodeOrientation(uint8_t flags, uint16_t seq, uint32_t time,
                              const float *q);
StatusPacket encodeStatus(Health health, uint8_t activity, uint8_t intensity,
                          uint32_t stamp, uint16_t io, uint16_t invalid,
                          uint16_t timing, uint16_t dropped, uint16_t eventId,
                          int16_t temperature);
} // namespace protocol
