import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import '../services/ble_transport.dart';

class DevicePicker extends StatefulWidget {
  const DevicePicker({super.key});
  @override
  State<DevicePicker> createState() => _PickerState();
}

class _PickerState extends State<DevicePicker> {
  final devices = <String, BleDevice>{};
  StreamSubscription<BleDevice>? sub;
  String state = 'Searching for KINETIQ wearables…';
  @override
  void initState() {
    super.initState();
    scan();
  }

  Future<void> scan() async {
    sub = UniversalBle.scanStream.listen((d) {
      if (mounted) setState(() => devices[d.deviceId] = d);
    });
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [motionServiceId]),
      );
      if (!mounted) await UniversalBle.stopScan();
    } catch (_) {
      if (mounted) {
        setState(
          () => state =
              'Bluetooth scan unavailable. Check Bluetooth and nearby-device permissions.',
        );
      }
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    UniversalBle.stopScan().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose wearable'),
    content: SizedBox(
      width: 360,
      child: devices.isEmpty
          ? Text(state)
          : ListView(
              shrinkWrap: true,
              children: [
                for (final d in devices.values)
                  ListTile(
                    title: Text(d.name ?? 'KINETIQ'),
                    subtitle: Text(d.deviceId),
                    onTap: () => Navigator.pop(context, d),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
