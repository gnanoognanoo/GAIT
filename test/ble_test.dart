import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetiq_motion/services/ble_protocol.dart';

Uint8List payload(int size, int sequence, int stamp) {
  final data = ByteData(size)
    ..setUint8(0, 1)
    ..setUint8(1, 3)
    ..setUint16(2, sequence, Endian.little)
    ..setUint32(4, stamp, Endian.little);
  if (size == 16) {
    data.setInt16(8, 16384, Endian.little);
  } else {
    data.setInt16(8, -1000, Endian.little);
    data.setInt16(14, 1234, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('Signed raw measurements and Q14 orientation decode', () {
    final raw = TelemetryPart.decode(
      payload(20, 65535, 0xfffffffe),
      orientation: false,
    );
    final q = TelemetryPart.decode(
      payload(16, 65535, 0xfffffffe),
      orientation: true,
    );
    expect(raw.values, [-1, 0, 0, 12.34, 0, 0]);
    expect(sensorEuler(q.values), [0, 0, 0]);
    final invalid = payload(16, 0, 1)..[9] = 0;
    expect(
      () => TelemetryPart.decode(invalid, orientation: true),
      throwsFormatException,
    );
    expect(
      () => TelemetryPart.decode(Uint8List(19), orientation: false),
      throwsFormatException,
    );
  });
  test(
    'Pairing accepts reverse arrival, counts gaps and handles both rollovers',
    () {
      final p = FramePairer();
      for (final (sequence, time) in [(65535, 0xfffffffe), (1, 3), (1, 3)]) {
        expect(
          p.add(
            TelemetryPart.decode(
              payload(16, sequence, time),
              orientation: true,
            ),
            orientation: true,
          ),
          isNull,
        );
        final pair = p.add(
          TelemetryPart.decode(payload(20, sequence, time), orientation: false),
          orientation: false,
        );
        if (p.received == 1) {
          expect(pair, isNotNull);
        }
      }
      expect(p.received, 2);
      expect(p.losses, 1);
    },
  );
  test('Status validates ranges and reports an unavailable temperature', () {
    final data = Uint8List(20)
      ..[0] = 1
      ..[1] = 2
      ..[19] = 128;
    expect(WearableHealth.decode(data).code, 2);
    expect(WearableHealth.decode(data).temperature, isNull);
    data[3] = 101;
    expect(() => WearableHealth.decode(data), throwsFormatException);
  });
}
