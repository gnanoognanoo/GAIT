# Open-source review

The selected firmware libraries are Adafruit MPU6050 (BSD), Adafruit BusIO (MIT), Adafruit Unified Sensor (Apache 2.0), x-io Technologies Fusion (MIT), and NimBLE-Arduino (Apache 2.0, with notices for its upstream components). The vendored Fusion source is unmodified. The exact upstream commits are recorded in the inventory. Adafruit examples declare GFX and SSD1306, which PlatformIO may resolve while installing Adafruit MPU6050. The project excludes those display libraries from the compiled firmware dependency graph.

The Flutter wrapper for model-viewer is Apache 2.0. The bundled Google JavaScript includes additional license headers and is identified by its content hash. The model itself is CC BY 4.0 by thunk3d.scanner. Retain attribution and the adaptation notice when distributing it. The app and standalone build should preserve the shipped notices. The Web build uses locally bundled renderer binaries.

Arduino-ESP32 includes LGPL-covered code and linked ESP-IDF components. PlatformIO tooling and compilers carry their own licences, including GPL-covered build tools. The resolved Flutter graph also contains MPL-2.0 bluez and dbus for Linux. They are recorded even though the delivered Android and web targets do not use Linux Bluetooth. MPL obligations apply if distributing covered files.

This inventory covers pinned upstream application libraries, the Dart lock graph, Android release Maven coordinates, model/font assets and major firmware build dependencies. The delivered artifacts are development builds. Before external distribution, verify corresponding-source and relinking obligations for each linked firmware core component, preserve native dependency and bundled JavaScript notices, and inventory the ESP-IDF and Flutter engine binary subcomponents. The SBOM currently does not enumerate each vendor SDK binary subcomponent. The release owner needs to verify these remaining redistribution obligations.

