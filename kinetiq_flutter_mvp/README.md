# KINETIQ

KINETIQ pairs an ESP32-WROOM-32 and a GY-521 MPU6050 with a Flutter movement dashboard. Home shows sensor axes, measured sensor orientation and an interactive model. Reports summarize local sessions. Profile manages local identity, the optional photo, the selected band and retention preferences.

## Firmware

The confirmed wiring is SDA GPIO 21 and SCL GPIO 22. The production modules are under firmware/src. PlatformIO and the generated Arduino IDE sketch build the same files. Follow the [firmware build and upload instructions](firmware/README.md) and use the matching Flutter build. The [BLE protocol](docs/ble_protocol.md) specifies the UUIDs, packet formats and command semantics.

## App

Use Flutter 3.38.9 with the supplied pubspec.lock.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build web --release --no-web-resources-cdn
```

Android uses the development signing identity for local installs. Distribution through app stores requires product signing. The iOS target requires Xcode and a signing team. The Web build runs on localhost or HTTPS. Web Bluetooth availability depends on the browser and host OS.

On Home, choose **Connect wearable**. Allow Bluetooth access, select the band and hold the device still for calibration. **Pause stream** leaves the connection active. **End session** releases it. **Start demo** works without a band. Demo history has its own selector in Reports. Choose a recorded date to export a daily PDF. Profile can export or clear recorded data.

The original scan, editable Blender file, GLB and rig validation scripts are included. A single IMU estimates the orientation of the segment that carries it. The leg’s bend is illustrative and yaw can drift. A sustained movement alert is opt-in and is recorded separately from the four activity states.

- [Architecture and measurement assumptions](docs/ARCHITECTURE.md)
- [Test and hardware verification](docs/VERIFICATION.md)
- [3D rig notes](docs/3D_RIG_NOTES.md)
- [Open-source notices and inventory](THIRD_PARTY_NOTICES.md)

