# ESP32-WROOM-32 firmware

Connect the assembled board over USB. The existing GY-521 wiring uses SDA GPIO 21, SCL GPIO 22 and address 0x68. The starting sensor configuration is ±8 g, ±500°/s and 21 Hz. The firmware checks the configured sensor before reporting data.

## PlatformIO

Use PlatformIO Core 6.1.19 or the PlatformIO IDE. From the repository root:

```sh
pio run -d firmware
pio device list
pio run -d firmware -t upload --upload-port COMx
pio device monitor -d firmware --port COMx -b 115200
```

Replace COMx with the board’s USB port. Close any other program using it. If USB auto-reset fails, hold BOOT while the upload connects, then release it. Reset the unit and hold it still for initial calibration.

## Arduino IDE

Open the generated firmware/arduino/KINETIQ_ESP32/KINETIQ_ESP32.ino in Arduino IDE 2. Install **esp32 by Espressif Systems 2.0.17** with Boards Manager. Choose **ESP32 Dev Module** and the board’s USB port. Install Adafruit MPU6050 2.2.6, Adafruit BusIO 1.17.4, Adafruit Unified Sensor 1.1.15 and NimBLE-Arduino 2.3.7. Fusion and all KINETIQ source modules are already bundled under the sketch’s src directory. Use Verify, then Upload. Open Serial Monitor at 115200 baud.

The PlatformIO source of truth is firmware/src. After an edit, regenerate the Arduino sketch from it with `python tools/export_firmware.py`. The export checks that every module is byte-identical. Arduino Library Manager may offer example-only display dependencies for MPU6050. This firmware requires BusIO and Unified Sensor.

In KINETIQ, tap Connect wearable, select the band and accept the OS pairing prompt. Keep the band still for calibration. The status and packet semantics are in docs/ble_protocol.md. Connect only after uploading this matching firmware version. The legacy service uses a different UUID. Stay near the band for the first discovery and pairing.

The default mounting axes match the board's printed orientation. The firmware configuration accepts a right-handed signed axis permutation. Establish the actual sensor-to-segment mount by comparing stationary poses and controlled rotations. Gravity references pitch and roll, while heading can drift without a magnetometer. The app displays relative yaw. The leg plays an illustrative bend. Establish device-specific activity thresholds and obtain physical acceptance before product deployment.

