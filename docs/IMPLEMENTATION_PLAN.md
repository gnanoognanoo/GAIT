# Implementation plan

1. Inspect the legacy firmware archive for board settings and inspect the original and rigged assets. Validate the existing KINETIQ rig independently of the legacy sketch.
2. Pin and inspect Adafruit MPU6050, BusIO, Unified Sensor, x-io Fusion and NimBLE-Arduino. Build modular Arduino source with PlatformIO and export those same files for Arduino IDE.
3. Freeze the four-characteristic BLE schema, including quantization and matched packet identity. Implement control, diagnostics, packet pairing, liveness tracking and reconnect.
4. Expose measured segment orientation separately from illustrative model movement. Retain local storage and reports with a compatible schema, batched writes and explicit activity classes.
5. Exercise firmware algorithms on the host, compile both firmware projects, run Flutter tests and builds, and verify the model. Record which checks require the assembled band and a real phone.
6. Package sources, dependency notices, SBOM, upload instructions, build artifacts and verification results.

