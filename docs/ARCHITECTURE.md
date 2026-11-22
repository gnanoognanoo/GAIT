# KINETIQ architecture

The Flutter project builds from the repository root. The PlatformIO project builds from firmware. Arduino IDE compiles a generated export of firmware/src. The distribution preserves original model files, the editable Blender scene, and the validated GLB.

## Firmware

SensorManager verifies identity and configures Adafruit MPU6050 over GPIO 21/22 at the Arduino default I²C clock. At the pinned version, Adafruit getEvent does not propagate BusIO read failure. The firmware uses the same Adafruit BusIO API for a checked 14-byte burst and converts with the configured sensitivities. A failed transfer is excluded and schedules a two-second restart. A full ADC scale excursion is surfaced as clipping. The 100 Hz scheduler advances using the microsecond clock, counts missed deadlines, and passes the actual elapsed interval to Fusion. The filter uses the requested ±8 g, ±500°/s and 21 Hz baseline.

Calibration collects a three-second stationary window. Each sample must be within 0.08 g of gravity and 4°/s norm, and the window must pass a gyro-variance check. This estimates gyro offset in the mapped sensor axes. A calibrated accelerometer sensitivity and full misalignment matrix require a multi-position procedure. FusionBias applies a 1°/s stationary threshold and four-second hold to limit runtime correction to quiet periods. Axis mapping defaults to the board frame. Select a right-handed permutation after establishing the physical mount. The offset is recalculated at boot, after I²C recovery, or on request.

The pinned Fusion AHRS uses NWU, no magnetometer, measured elapsed seconds, 500°/s hardware range, 0.5 gain, 10° acceleration rejection and a five-second rejection timeout. Those initial settings use the upstream practical gain and rejection guidance and balance tilt retention during acceleration with reacquisition. They require hardware evaluation. Quaternion magnitude is verified before quantizing. Fusion startup and recovery suppress activity classification. Sensor error, clipping and timing are available through BLE status and one-second serial JSON counters.

Motion analysis combines RMS-weighted gravity-removed acceleration and corrected rotation. Normalization uses 0.65 g and 150°/s as initial engineering scales. The exponential time constant is 250 ms. The four states enter at 0.07, 0.22 and 0.50 normalized intensity, with exit thresholds at 75% to reduce chatter. Transition events use an 800 ms global cooldown. Tune these values against representative wearable data.

## App

Universal BLE discovers the advertised service, subscribes to raw, orientation and status characteristics, and owns the connection retry lifecycle. Decoding and packet pairing live separately from transport. Home exposes stream controls, calibration status, connection quality, sensor axes and measured segment orientation. The leg displays illustrative flexion driven by activity. The alert ring follows an opt-in sustained-high condition and episode events are timestamped. Heading can drift. Joint flexion requires independently observed thigh and lower-leg orientations. The telemetry decoder is per link, so a future dual-IMU design can pair time-aligned segment streams before calculating their relative rotation.

The encrypted Hive CE store is shared across Android and Web and preserves installed data. New record fields are nullable so older rows remain readable. A one-second or 64-reading buffer groups writes and flushes on stop. The secure key is kept by platform secure storage. Profiles, selected device IDs and avatar thumbnails remain local. Daily reports derive motion distribution, observed duration and alert history from persisted records. Availability covers valid recorded intervals and cannot establish wear duration when the app was disconnected. Android and Web PDF exports run locally.

