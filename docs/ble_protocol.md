# KINETIQ BLE protocol

Version 1 uses a dedicated four-characteristic service. UUIDs are shared by the PlatformIO firmware, Arduino export and Flutter app.

| GATT attribute | UUID | Operation |
| --- | --- | --- |
| Service | 8f6d0001-7a1b-4c2e-9f52-2a6e4b1c0001 | Advertised in legacy primary advertising data |
| Raw sensors | 8f6d0002-7a1b-4c2e-9f52-2a6e4b1c0001 | Notify |
| Orientation | 8f6d0003-7a1b-4c2e-9f52-2a6e4b1c0001 | Notify |
| Control | 8f6d0004-7a1b-4c2e-9f52-2a6e4b1c0001 | Encrypted write with response |
| Status | 8f6d0005-7a1b-4c2e-9f52-2a6e4b1c0001 | Encrypted read and notify |

The advertised scan response includes the name KINETIQ. Firmware starts link encryption and requests Secure Connections bonding through Just Works. Without a display or confirmation input, this pairing mode has no authenticated proof of device ownership. Telemetry is sent only on the encrypted connection. The application subscribes to all three notifications before sending Start. A disconnect clears streaming intent on the peripheral. Flutter rediscovers and resubscribes on reconnect, then restores the user's pause or resume choice.

## Common header

All multibyte fields are little-endian. Both motion notifications share the same header for each sample.

| Offset | Type | Field |
| --- | --- | --- |
| 0 | uint8 | Protocol version, 1 |
| 1 | uint8 | Flags |
| 2 | uint16 | Sequence modulo 65536 |
| 4 | uint32 | Device uptime in milliseconds modulo 2³² |

| Bit | Meaning |
| --- | --- |
| 0 | Sensor transfer valid |
| 1 | Stationary calibration valid |
| 2 | Movement detected |
| 3 | HIGH_ACTIVITY |
| 4 | Fusion ignored the accelerometer vector |
| 5 | Fusion gyro overrange recovery or raw gyro wire range exceeded |
| 6 | Fusion startup or recovery |
| 7 | Reserved, zero |

### Raw sensor notification

20 bytes. Bytes 8–13 are int16 X, Y and Z acceleration in mg. Bytes 14–19 are int16 X, Y and Z gyroscope in centidegrees/s. Raw values are scaled ADC readings in the configured mounting frame before gyro bias correction. Acceleration includes gravity. Gyro values outside −327.68 to +327.67°/s saturate on the wire even though the MPU6050 can measure ±500°/s. Bit 5 signals the limitation and Flutter omits the gyro axes for that frame. AHRS uses the full-precision input. Actual ADC clipping is a status fault and the saturated sample is excluded from fusion and streaming.

### Orientation notification

16 bytes. Bytes 8–15 are signed int16 W, X, Y and Z quaternions, in that order, divided by 16384 to decode. The quaternion expresses the mapped IMU orientation in the Fusion NWU frame. Flutter accepts quaternions within 0.02 of unit norm, renormalizes them, and suppresses displayed orientation during startup and recovery. Roll and pitch use gravity to recover tilt. Yaw is relative to startup and can drift.

The receiver validates sizes, version, flags, and quaternion magnitude. It joins pairs by both sequence and timestamp. Duplicate and old pairs are discarded. Sequence gaps contribute to connection quality and break the continuous alert window. Stale status or stalled telemetry triggers reconnection. BLE notifications target 50 paired samples/s, or 100 notifications/s. The measured host display and retention rate is capped near 10 paired samples/s, with activity changes forwarded immediately. This is rate limiting, distinct from on-air packet loss.

## Status notification

20 bytes, every 200 ms, on motion-state change, and in response to control commands.

| Offset | Type | Field |
| --- | --- | --- |
| 0 | uint8 | Protocol version, 1 |
| 1 | uint8 | Health, 0 ready, 1 MPU6050 unavailable, 2 hold still for calibration, 3 I²C failure, 4 sensor clipping, 5 timing/fusion failure |
| 2 | uint8 | STATIONARY 0, LOW_MOTION 1, ACTIVE_MOTION 2, HIGH_ACTIVITY 3 |
| 3 | uint8 | Activity intensity 0–100 |
| 4 | uint32 | Device uptime in ms |
| 8 | uint16 | I²C failure count |
| 10 | uint16 | Invalid/clipped sample count |
| 12 | uint16 | Missed sampling schedule count |
| 14 | uint16 | Failed notification pair submissions |
| 16 | uint16 | Movement transition event counter modulo 65536 |
| 18 | int16 | Die temperature in hundredths of a degree Celsius, −32768 unavailable |

Status and raw/orientation are separate GATT queues. For moving non-high samples, the client requires fresh status for LOW_MOTION or ACTIVE_MOTION. A missed or late status can temporarily produce Unclassified. Host receipt time is the local report timestamp. Device uptime and the latest event counter are retained with the record. High activity has no clinical interpretation. Alert episodes use a separate user-configured rule.

## Commands

Write exactly one byte with response. 0x01 starts motion streaming, 0x02 pauses motion streaming, 0x03 requests stationary recalibration, and 0x04 requests immediate status. Invalid lengths and codes are ignored. A successful write acknowledges GATT reception. Status reports the sensor state. Streaming remains inactive until Start. Status stays available while motion streaming is paused.

