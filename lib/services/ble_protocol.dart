import 'dart:math' as math;
import 'dart:typed_data';

const motionServiceId = '8f6d0001-7a1b-4c2e-9f52-2a6e4b1c0001';
const rawCharacteristicId = '8f6d0002-7a1b-4c2e-9f52-2a6e4b1c0001';
const orientationCharacteristicId = '8f6d0003-7a1b-4c2e-9f52-2a6e4b1c0001';
const controlCharacteristicId = '8f6d0004-7a1b-4c2e-9f52-2a6e4b1c0001';
const statusCharacteristicId = '8f6d0005-7a1b-4c2e-9f52-2a6e4b1c0001';

enum WearableCommand { start, stop, calibrate, status }

ByteData _packet(Uint8List data, int size) {
  if (data.length != size || data[0] != 1) {
    throw const FormatException('Unsupported packet');
  }
  return ByteData.sublistView(data);
}

class TelemetryPart {
  TelemetryPart(this.flags, this.sequence, this.stamp, this.values);
  final int flags, sequence, stamp;
  final List<double> values;
  (int, int) get key => (sequence, stamp);
  bool get ready => (flags & 3) == 3;
  bool get orienting => (flags & 64) != 0;
  bool get overrange => (flags & 32) != 0;
  factory TelemetryPart.decode(Uint8List data, {required bool orientation}) {
    final b = _packet(data, orientation ? 16 : 20), flags = data[1];
    if ((flags & 128) != 0 || ((flags & 8) != 0 && (flags & 4) == 0)) {
      throw const FormatException('Invalid flags');
    }
    final v = List.generate(
      orientation ? 4 : 6,
      (i) =>
          b.getInt16(8 + i * 2, Endian.little) /
          (orientation
              ? 16384
              : i < 3
              ? 1000
              : 100),
    );
    if (orientation) {
      final norm = math.sqrt(v.fold(0.0, (n, x) => n + x * x));
      if ((norm - 1).abs() > .02) {
        throw const FormatException('Invalid quaternion');
      }
      for (int i = 0; i < v.length; i++) {
        v[i] /= norm;
      }
    }
    return TelemetryPart(
      flags,
      b.getUint16(2, Endian.little),
      b.getUint32(4, Endian.little),
      v,
    );
  }
}

class WearableHealth {
  WearableHealth(
    this.code,
    this.activity,
    this.intensity,
    this.stamp,
    this.counters,
    this.event,
    this.temperature,
  );
  final int code, activity, intensity, stamp, event;
  final List<int> counters;
  final double? temperature;
  String get label => const [
    'Ready',
    'MPU6050 unavailable',
    'Hold band still for calibration',
    'I²C transfer failed',
    'Sensor clipped',
    'Sample timing interrupted',
  ][code];
  factory WearableHealth.decode(Uint8List data) {
    final b = _packet(data, 20);
    if (data[1] > 5 || data[2] > 3 || data[3] > 100) {
      throw const FormatException('Invalid status');
    }
    int word(int p) => b.getUint16(p, Endian.little);
    final temp = b.getInt16(18, Endian.little);
    return WearableHealth(
      data[1],
      data[2],
      data[3],
      b.getUint32(4, Endian.little),
      List.generate(4, (i) => word(8 + i * 2)),
      word(16),
      temp == -32768 ? null : temp / 100,
    );
  }
}

class FramePairer {
  final _raw = <(int, int), TelemetryPart>{},
      _angles = <(int, int), TelemetryPart>{};
  int? _sequence, _stamp;
  int losses = 0, received = 0;
  (TelemetryPart, TelemetryPart)? add(
    TelemetryPart p, {
    required bool orientation,
  }) {
    final source = orientation ? _angles : _raw,
        other = orientation ? _raw : _angles;
    final match = other.remove(p.key);
    if (match == null) {
      source[p.key] = p;
      if (source.length > 16) source.remove(source.keys.first);
      return null;
    }
    if (match.flags != p.flags) {
      throw const FormatException('Paired flags differ');
    }
    final last = _sequence, lastStamp = _stamp;
    if (last != null && lastStamp != null) {
      final delta = (p.sequence - last) & 65535,
          timeDelta = (p.stamp - lastStamp) & 0xffffffff;
      if (delta == 0 || delta > 0x8000 || timeDelta > 0x80000000) return null;
      losses += delta - 1;
    }
    _sequence = p.sequence;
    _stamp = p.stamp;
    received++;
    return orientation ? (match, p) : (p, match);
  }
}

List<double> sensorEuler(List<double> q) {
  final [w, x, y, z] = q;
  const degrees = 180 / math.pi;
  return [
    math.atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y)) * degrees,
    math.asin((2 * (w * y - z * x)).clamp(-1, 1)) * degrees,
    math.atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z)) * degrees,
  ];
}
