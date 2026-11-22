import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetiq_motion/models/motion_sample.dart';
import 'package:kinetiq_motion/services/ble_transport.dart';
import 'package:kinetiq_motion/widgets/device_picker.dart';
import 'package:universal_ble/universal_ble.dart';
import 'ble_test.dart' show payload;

class SimulatedBle extends UniversalBlePlatform {
  ScanFilter? filter;
  final subscriptions = <String>[];
  final commands = <int>[];
  int discoveries = 0, disconnections = 0;
  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    filter = scanFilter;
    updateScanResult(
      BleDevice(
        deviceId: 'test-band',
        name: 'KINETIQ test',
        services: [motionServiceId],
      ),
    );
  }

  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
  }) async {
    updateConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnections++;
    updateConnection(deviceId, false);
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async {
    discoveries++;
    return [];
  }

  @override
  Future<void> setNotifiable(
    String deviceId,
    String service,
    String characteristic,
    BleInputProperty property,
  ) async {
    expect(service, motionServiceId);
    subscriptions.add(characteristic);
  }

  void emit(String characteristic, Uint8List bytes) =>
      updateCharacteristicValue('test-band', characteristic, bytes, null);
  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty property,
  ) async {
    expect(service, motionServiceId);
    expect(characteristic, controlCharacteristicId);
    commands.add(value.single);
    if (value.single == WearableCommand.start.index + 1) {
      emit(statusCharacteristicId, Uint8List(20)..[0] = 1);
      emit(orientationCharacteristicId, payload(16, 1, 20));
      emit(rawCharacteristicId, payload(20, 1, 20));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Picker filters by the wearable service and presents a discovered device',
    (tester) async {
      final platform = SimulatedBle();
      UniversalBle.setInstance(platform);
      BleDevice? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showDialog<BleDevice>(
                    context: context,
                    builder: (_) => const DevicePicker(),
                  );
                },
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(platform.filter?.withServices, [motionServiceId]);
      await tester.tap(find.text('KINETIQ test'));
      await tester.pumpAndSettle();
      expect(selected?.deviceId, 'test-band');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'Link subscribes before Start, decodes a frame, detects silence and disconnects',
    () async {
      final platform = SimulatedBle();
      UniversalBle.setInstance(platform);
      final sample = Completer<Reading>(), stale = Completer<void>();
      final link = WearableLink('test-band', (status, valid) {
        if (status == 'Telemetry stale' && !stale.isCompleted) stale.complete();
      });
      final sub = link.subscribe().listen((line) {
        if (!sample.isCompleted) sample.complete(Reading.parse(line)!);
      }, onError: sample.completeError);
      try {
        final result = await sample.future.timeout(const Duration(seconds: 4));
        expect(result.motion, Motion.stationary);
        expect(result.axes['ax'], -1);
        expect(result.quaternion, [1, 0, 0, 0]);
        expect(platform.discoveries, 1);
        expect(platform.subscriptions, [
          statusCharacteristicId,
          rawCharacteristicId,
          orientationCharacteristicId,
        ]);
        expect(platform.commands, [4, 1]);
        await stale.future.timeout(const Duration(seconds: 4));
        await link.command(WearableCommand.stop);
        expect(platform.commands.last, 2);
        platform.updateConnection('test-band', false);
        for (var n = 0; n < 40 && platform.commands.length < 5; n++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(platform.discoveries, 2);
        expect(platform.subscriptions.length, 6);
        expect(platform.commands.sublist(3), [4, 2]);
      } finally {
        await sub.cancel();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(platform.disconnections, 2);
    },
  );
}
