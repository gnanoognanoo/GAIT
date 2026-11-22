import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/motion_sample.dart';
import 'local_store.dart';
import 'analytics.dart';
import 'orientation.dart';
import 'ble_transport.dart';

class MotionDataService extends ChangeNotifier {
  MotionDataService(this.store)
    : history = store.readEvents(),
      profile = store.profile;
  final LocalStore store;
  final List<MotionSample> history;
  Map<String, dynamic> profile;
  final recent = <MotionSample>[];
  Timer? _demoTimer, _staleTimer;
  int _segment = 0;
  StreamSubscription<String>? _input;
  String? session;
  bool demo = false;
  MotionSample? latest;
  DateTime? _highSince;
  Duration monitored = Duration.zero;
  int sessionAlerts = 0, rejected = 0;
  String? error;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  final orientation = Orientation();
  int _tick = 0;
  int get threshold => (profile['threshold'] as int?) ?? 0;
  bool get retain => profile['retain'] != false;
  bool get active => session != null;
  void _update() {
    if (!_disposed) notifyListeners();
  }

  void _begin(bool simulated) {
    stop();
    demo = simulated;
    session = DateTime.now().microsecondsSinceEpoch.toString();
    monitored = Duration.zero;
    recent.clear();
    sessionAlerts = 0;
    rejected = 0;
    _tick = 0;
    error = null;
    _update();
  }

  void startDemo() {
    _begin(true);
    void tick() {
      final high = _tick % 32 >= 10;
      final wave = math.sin(_tick * .62);
      ingest(
        Reading(high ? Motion.high : Motion.low, {
          'ax': .08 * wave,
          'ay': .1 * wave,
          'az': 1 + (high ? .12 : .015) * wave,
          'gx': (high ? 43 : 3) * wave,
          'gy': 2 * wave,
          'gz': wave,
        }),
        DateTime.now(),
      );
      _tick++;
    }

    tick();
    _demoTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  WearableLink? wearable;
  void connectWearable(String id) {
    final link = WearableLink(id, sensorStatus);
    connect(link.subscribe(), label: 'BLE · connecting');
    wearable = link;
  }

  final _pending = <MotionSample>[];
  Timer? _batchTimer;
  String linkLabel = 'USB serial';
  void sensorStatus(String value, bool valid) {
    if (!active || demo) return;
    linkLabel = 'BLE · $value';
    if (!valid && latest != null) {
      latest = null;
      _highSince = null;
      orientation.reset();
      _staleTimer?.cancel();
      _segment++;
    }
    _update();
  }

  void connect(Stream<String> lines, {String label = 'USB serial'}) {
    linkLabel = label;
    _begin(false);
    final id = session;
    _input = lines.listen(
      (line) {
        if (id == session) ingestMotionLine(line);
      },
      onDone: () {
        if (id == session) stop();
      },
      onError: (Object e) {
        if (id == session) {
          stop();
          error = 'The device stream was interrupted.';
          _update();
        }
      },
      cancelOnError: true,
    );
  }

  void ingestMotionLine(String line) {
    if (!active || demo) return;
    final reading = Reading.parse(line);
    if (reading == null) {
      rejected++;
      _update();
      return;
    }
    ingest(reading, DateTime.now());
  }

  void ingest(Reading reading, DateTime time) {
    final id = session;
    if (id == null) return;
    final last = latest;
    final gap = last == null ? null : time.difference(last.time);
    if (gap != null && gap.isNegative) {
      rejected++;
      _update();
      return;
    }
    final continuous = gap != null && gap <= DailyReport.continuityLimit;
    if (continuous) monitored += gap;
    if (!continuous || reading.motion != Motion.high) _highSince = null;
    if (reading.motion == Motion.high) _highSince ??= time;
    final alert =
        threshold > 0 &&
        _highSince != null &&
        time.difference(_highSince!).inSeconds >= threshold;
    final onset = alert && (!continuous || last?.alert != true);
    final sample = MotionSample(
      time,
      "$id-$_segment",
      demo,
      reading,
      alert,
      onset,
    );
    if (onset) sessionAlerts++;
    if (last == null ||
        !continuous ||
        reading.motion != last.reading.motion ||
        alert != last.alert) {
      recent.insert(0, sample);
      if (recent.length > 10) recent.removeLast();
    }
    orientation.update(reading, time);
    latest = sample;
    if (!demo) {
      _staleTimer?.cancel();
      _staleTimer = Timer(
        DailyReport.continuityLimit + const Duration(milliseconds: 1),
        () {
          latest = null;
          _highSince = null;
          orientation.reset();
          _segment++;
          _update();
        },
      );
    }
    if (retain) {
      _pending.add(sample);
      _batchTimer ??= Timer(const Duration(seconds: 1), _flush);
      if (_pending.length >= 64) _flush();
    }
    _update();
  }

  void _flush() {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_pending.isEmpty) return;
    final batch = List<MotionSample>.of(_pending);
    _pending.clear();
    _writes = _writes
        .then((_) async {
          await store.appendBatch(batch);
          history.addAll(batch);
          _update();
        })
        .catchError((Object e) {
          error =
              'A batch of readings could not be saved. Check device storage.';
          _update();
        });
  }

  Future<void> get flushed {
    _flush();
    return _writes;
  }

  void stop() {
    _flush();
    wearable = null;
    _staleTimer?.cancel();
    _demoTimer?.cancel();
    _demoTimer = null;
    unawaited(_input?.cancel());
    _input = null;
    orientation.reset();
    session = null;
    latest = null;
    _highSince = null;
    _update();
  }

  Future<void> save(Map<String, dynamic> next) async {
    await store.saveProfile(next);
    if (next['threshold'] != profile['threshold']) _highSince = null;
    if ((next['retain'] != false) != retain) {
      _segment++;
      _highSince = null;
    }
    profile = next;
    _update();
  }

  Future<void> clear() async {
    stop();
    await _writes;
    await store.clearHistory();
    history.clear();
    recent.clear();
    monitored = Duration.zero;
    sessionAlerts = 0;
    rejected = 0;
    _update();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
