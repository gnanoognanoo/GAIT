# KINETIQ verification

The software tests use the confirmed GPIO and range settings. No physical Android phone or ESP32 serial port was visible at verification time.

| Check | Result |
| --- | --- |
| PlatformIO | ESP32 Dev Module release build using espressif32 6.10.0, Arduino-ESP32 2.0.17, Adafruit MPU6050 2.2.6 and NimBLE-Arduino 2.3.7 |
| ESP32 memory | PlatformIO reported 639,945 bytes flash payload and 36,716 bytes static RAM. Arduino CLI reported 630,825 bytes and 36,652 bytes respectively |
| Arduino export | Independently compiled with Arduino CLI 1.3.1, ESP32 Dev Module FQBN and the same dependencies. Each generated source module was compared byte for byte against firmware/src |
| Firmware host test | Passed with Zig 0.15.2 using synthetic stationary samples, motion rejection, watchdog interval rejection, bias estimation, controlled 90° roll, quaternion normalization, motion events and little-endian packet fixtures |
| BLE contract | All five UUIDs match firmware, Flutter and documentation. Flutter tests check signed raw values, Q14 normalization, status decoding, reversed arrival, duplicate frames, gaps and sequence/timestamp rollover |
| Static analysis | Flutter analyze reported no issues. |
| Flutter tests | Twelve tests cover simulated BLE scan/filter/selection, connection, discovery, subscriptions, stale data, reconnect and teardown, decoding, local encrypted storage, activity and alert transitions, reports, PDF generation, profile editing and navigation at 360 and 1024 logical pixels |
| USB import | Node test passed for split packets, maximum line length, port release and incomplete trailing input |
| Original and supplied rigged assets | Inspected the original geometry and validated the prior rigged export. The two downloaded rigged copies had identical SHA-256 and the same KneeFlexionDemo animation |
| Integrated 3D model | Khronos validation reported zero errors and warnings. Blender reimport verified weights, rest/flexed/return poses, centered ring, approximate 0.315-unit peak point displacement and edge length ratios at the first/99th percentiles of 0.836 and 1.192 |
| Web build | JavaScript release compiled with local Flutter renderer and model assets. Optional Wasm dry run reported a transitive image codec compatibility lint |
| Browser smoke test | Chrome rendered the complete local leg, played the 2.04-second flexion clip, switched the ring on and off with the configured alert, recorded 30 demo samples and downloaded a 6,138-byte PDF |
| Android build | Release APK built, APK v2 signature verified, and packaged GLB was byte-identical to the web and workspace asset. Android API 36.1 emulator installed the APK and rendered the Home dashboard and complete native GLB. Startup was slow in the emulator |
| iOS | Configured for CocoaPods/Xcode with Bluetooth and photo-library permission strings. Build and device testing require macOS and an iPhone |

## Physical acceptance

1. Upload the matching firmware using the board’s actual USB port. Inspect the 115200-baud JSON output for sensor discovery and sampling.
2. Keep the assembled band still for initial calibration. Check that movement during calibration delays acceptance. Exercise disconnection and recovery of the I²C sensor on the bench where accessible.
3. Install the Android APK on a real phone. Confirm permission prompting, legacy advertisement discovery, selection, OS pairing/bonding, encrypted control writes and all three notifications.
4. Compare the reported axes to stationary gravity at known poses, then compare orientation during controlled rotations. Check mount-axis direction, relative yaw drift, latency and clipping.
5. Record serial sample and transmission counters plus the app’s paired-frame percentage during a ten-minute run. Check throughput at 50 pairs/s, interruption/reconnect, duplicate handling and restarting the peripheral.
6. Verify pause, resume and recalibration from the phone. Confirm stale readings disappear, live sessions persist, the high-activity animation responds and reports reflect recorded data.
7. Exercise representative movements with the band worn as intended. Review the score scales, state thresholds, cooldown and alert rule with collected data before field use.

Software verification covers build and algorithm behavior. This project has not been flashed or tested on the physical ESP32, connected MPU6050 or real Android phone in this session.

