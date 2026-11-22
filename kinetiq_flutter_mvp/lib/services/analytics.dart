import '../models/motion_sample.dart';

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
String dayKey(DateTime t) => t.toIso8601String().split('T').first;
String clockText(DateTime t) => t.toIso8601String().substring(11, 19);
String durationText(Duration d) => d.inHours > 0
    ? '${d.inHours}h ${d.inMinutes % 60}m'
    : '${d.inMinutes}m ${d.inSeconds % 60}s';

class DailyReport {
  DailyReport(List<MotionSample> history, this.date, this.demo) {
    final start = dayOf(date),
        end = DateTime(date.year, date.month, date.day + 1);
    final prior = <String, int>{};
    final latest = <String, MotionSample>{};
    for (final s in history.where((s) => s.demo == demo)) {
      final prev = latest[s.session];
      if (prev != null && s.time.isAfter(prev.time)) {
        final left = prev.time.isBefore(start) ? start : prev.time;
        final right = s.time.isAfter(end) ? end : s.time;
        if (right.isAfter(left)) {
          final overlap = right.difference(left);
          span += overlap;
          if (s.time.difference(prev.time) <= continuityLimit) {
            covered += overlap;
          }
        }
      }
      latest[s.session] = s;
      if (s.time.isBefore(start)) {
        prior.update(dayKey(s.time), (n) => n + 1, ifAbsent: () => 1);
      } else if (s.time.isBefore(end)) {
        samples.add(s);
        hourly[s.time.hour]++;
        if (s.reading.motion == Motion.high) high++;
        if (s.reading.motion == Motion.low) low++;
        if (s.reading.motion == Motion.stationary) stationary++;
        if (s.reading.motion == Motion.active) active++;
        final deviceEvent = s.reading.deviceEvent;
        if (deviceEvent != null &&
            prev?.reading.deviceEvent != null &&
            prev!.reading.deviceEvent != deviceEvent) {
          final delta = (deviceEvent - prev.reading.deviceEvent!) & 65535;
          if (delta < 32768) movementEvents += delta;
        }
        if (s.alertStart) alerts.add(s);
      }
    }
    final days = prior.keys.toList()..sort();
    if (days.isNotEmpty) {
      previousDate = days.last;
      previousCount = prior[days.last];
    }
  }
  static const continuityLimit = Duration(seconds: 5);
  final DateTime date;
  final bool demo;
  final samples = <MotionSample>[], alerts = <MotionSample>[];
  final hourly = List<int>.filled(24, 0);
  int low = 0, high = 0, stationary = 0, active = 0, movementEvents = 0;
  int get unclassified => samples.length - low - high - stationary - active;
  Duration covered = Duration.zero, span = Duration.zero;
  String? previousDate;
  int? previousCount;
  int? get availability => span.inMilliseconds == 0
      ? null
      : (100 * covered.inMilliseconds / span.inMilliseconds).round();
  String get insight {
    if (samples.isEmpty) return 'No readings were recorded on this day.';
    final peak = hourly.indexOf(hourly.reduce((a, b) => a > b ? a : b));
    final comparison = previousCount == null
        ? 'This is the first recorded day in this history.'
        : 'The previous recorded day ($previousDate) had $previousCount readings.';
    final advice = alerts.isEmpty
        ? 'Review the hourly pattern alongside your session times.'
        : 'Review the timestamps of sustained high-motion episodes below.';
    return 'Recorded ${samples.length} ${samples.length == 1 ? 'reading' : 'readings'}, with the most samples in the hour beginning ${peak.toString().padLeft(2, '0')}:00. '
        'High-motion readings: $high. Alert episodes: ${alerts.length}. $comparison $advice';
  }
}
