import 'dart:convert';

enum Motion {
  low,
  high,
  unknown,
  stationary,
  active;

  String get display => switch (this) {
    low => 'LOW MOTION',
    high => 'HIGH ACTIVITY',
    unknown => 'Unclassified',
    stationary => 'STATIONARY',
    active => 'ACTIVE MOTION',
  };
}

class Reading {
  const Reading(
    this.motion, [
    this.axes = const {},
    this.intensity,
    this.quaternion,
    this.deviceTime,
    this.deviceEvent,
  ]);
  final List<double>? quaternion;
  final int? deviceTime, deviceEvent;
  final int? intensity;
  final Motion motion;
  final Map<String, double> axes;
  static const axisNames = ['ax', 'ay', 'az', 'gx', 'gy', 'gz'];

  static Reading? parse(String line) {
    if (line.length > 1024) return null;
    Motion? label(Object? value) =>
        switch (value?.toString().trim().toUpperCase()) {
          'LOW' || 'LOW MOTION' => Motion.low,
          'HIGH' || 'HIGH MOTION' => Motion.high,
          'STATIONARY' => Motion.stationary,
          'ACTIVE' => Motion.active,
          'UNKNOWN' => Motion.unknown,
          _ => null,
        };
    final simple = label(line);
    if (simple != null) return Reading(simple);
    try {
      final json = jsonDecode(line);
      if (json is! Map<String, dynamic>) return null;
      final state = label(json['motion']);
      if (json.containsKey('motion') && state == null) return null;
      final axes = <String, double>{};
      for (final key in axisNames.where(json.containsKey)) {
        final value = json[key];
        if (value is! num || !value.isFinite) return null;
        axes[key] = value.toDouble();
      }
      if (state == null && axes.isEmpty) return null;
      final intensity = json['intensity'];
      if (intensity != null &&
          (intensity is! int || intensity < 0 || intensity > 100)) {
        return null;
      }
      final q = json['quaternion'];
      if (q != null &&
          (q is! List ||
              q.length != 4 ||
              q.any((v) => v is! num || !v.isFinite))) {
        return null;
      }
      final time = json['deviceTime'], event = json['event'];
      if ((time != null && time is! int) || (event != null && event is! int)) {
        return null;
      }
      return Reading(
        state ?? Motion.unknown,
        axes,
        intensity as int?,
        (q as List?)?.map((v) => (v as num).toDouble()).toList(),
        time as int?,
        event as int?,
      );
    } on FormatException {
      return null;
    }
  }
}

class MotionSample {
  const MotionSample(
    this.time,
    this.session,
    this.demo,
    this.reading,
    this.alert,
    this.alertStart,
  );
  final DateTime time;
  final String session;
  final bool demo, alert, alertStart;
  final Reading reading;
  Map<String, dynamic> toMap() => {
    't': time.millisecondsSinceEpoch,
    's': session,
    'demo': demo,
    'motion': reading.motion.name,
    'axes': reading.axes,
    'intensity': reading.intensity,
    'q': reading.quaternion,
    'deviceTime': reading.deviceTime,
    'deviceEvent': reading.deviceEvent,
    'alert': alert,
    'start': alertStart,
  };
  factory MotionSample.fromMap(Map m) => MotionSample(
    DateTime.fromMillisecondsSinceEpoch(m['t'] as int),
    m['s'] as String,
    m['demo'] as bool,
    Reading(
      Motion.values.byName(m['motion'] as String),
      Map<String, double>.from(m['axes'] as Map),
      m['intensity'] as int?,
      (m['q'] as List?)?.cast<double>(),
      m['deviceTime'] as int?,
      m['deviceEvent'] as int?,
    ),
    m['alert'] as bool,
    m['start'] as bool,
  );
}
