import 'dart:math' as math;
import '../models/motion_sample.dart';

/// Relative sensor roll around its X axis, in degrees. Uses the provisional
/// g and degrees/second units only when all six axes are supplied.
class Orientation {
  bool collecting = false;
  double? relative;
  double _zero = 0, _bias = 0, _sx = 0, _sy = 0, _rate = 0;
  int _count = 0;
  DateTime? _last;
  void reset() {
    collecting = false;
    relative = null;
    _last = null;
    _count = 0;
  }

  void begin() {
    reset();
    collecting = true;
    _sx = 0;
    _sy = 0;
    _rate = 0;
  }

  void update(Reading r, DateTime now) {
    final a = r.axes;
    if (!Reading.axisNames.every(a.containsKey)) {
      reset();
      return;
    }
    final dt = _last == null
        ? 0.0
        : now.difference(_last!).inMicroseconds / 1e6;
    if (dt < 0 || dt > 2) {
      reset();
      return;
    }
    _last = now;
    final g = math.sqrt(
      a['ax']! * a['ax']! + a['ay']! * a['ay']! + a['az']! * a['az']!,
    );
    final angle = math.atan2(a['ay']!, a['az']!);
    if (collecting) {
      if ((g - 1).abs() > .08 ||
          ['gx', 'gy', 'gz'].any((k) => a[k]!.abs() > 3)) {
        begin();
        return;
      }
      _sx += math.cos(angle);
      _sy += math.sin(angle);
      _rate += a['gx']!;
      _count++;
      if (_count == 10) {
        _zero = math.atan2(_sy, _sx) * 180 / math.pi;
        _bias = _rate / _count;
        relative = 0;
        collecting = false;
      }
    } else if (relative != null) {
      final predicted = relative! + (a['gx']! - _bias) * dt;
      final residual =
          (angle * 180 / math.pi - _zero - predicted + 180) % 360 - 180;
      relative =
          predicted +
          ((g - 1).abs() < .12 ? (1 - math.exp(-dt / .5)) * residual : 0);
    }
  }
}
