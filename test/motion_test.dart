import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kinetiq_motion/models/motion_sample.dart';
import 'package:kinetiq_motion/services/analytics.dart';
import 'package:kinetiq_motion/services/exports.dart';
import 'package:kinetiq_motion/services/local_store.dart';
import 'package:kinetiq_motion/services/motion_data_service.dart';
import 'package:kinetiq_motion/services/orientation.dart';

void main() {
  test('Labels and partial JSON preserve absent data', () {
    for (final s in ['HIGH', ' high motion\r', 'LOW', 'LOW MOTION']) {
      expect(Reading.parse(s)!.axes, isEmpty);
    }
    expect(Reading.parse('{"ax":0,"gz":-7.5}')!.motion, Motion.unknown);
    expect(Reading.parse('{"motion":"LOW","ax":0}')!.axes, {'ax': 0.0});
    for (final s in [
      '',
      '[]',
      '{}',
      'noise',
      '{"motion":"other"}',
      '{"gx":"8"}',
      '{"ax":1e999}',
    ]) {
      expect(Reading.parse(s), isNull);
    }
  });
  test(
    'Calibrated roll requires stationary complete data and resets on gaps',
    () {
      final o = Orientation()..begin(), t = DateTime(2026);
      const still = Reading(Motion.low, {
        'ax': 0,
        'ay': 0,
        'az': 1,
        'gx': 1,
        'gy': 0,
        'gz': 0,
      });
      for (int i = 0; i < 10; i++) {
        o.update(still, t.add(Duration(milliseconds: 100 * i)));
      }
      expect(o.relative, 0);
      o.update(
        const Reading(Motion.high, {
          'ax': 0,
          'ay': 1,
          'az': 0,
          'gx': 91,
          'gy': 0,
          'gz': 0,
        }),
        t.add(const Duration(seconds: 1)),
      );
      expect(o.relative, greaterThan(9));
      o.update(still, t.add(const Duration(seconds: 7)));
      expect(o.relative, isNull);
    },
  );
  test(
    'Report isolates source, splits midnight and excludes gaps and session boundaries',
    () async {
      final t = DateTime(2026, 1, 2);
      MotionSample sample(int sec, String id, [bool demo = false]) =>
          MotionSample(
            t.add(Duration(seconds: sec)),
            id,
            demo,
            const Reading(Motion.high),
            false,
            false,
          );
      final history = [
        sample(-2, 'a'),
        sample(2, 'a'),
        sample(22, 'a'),
        sample(23, 'b'),
        sample(24, 'b'),
        sample(25, 'demo', true),
      ];
      final report = DailyReport(history, t, false);
      expect(report.covered.inSeconds, 3);
      expect(report.span.inSeconds, 23);
      expect(report.availability, 13);
      expect(report.samples.length, 4);
      expect(report.high, 4);
      expect(report.previousCount, 1);
      expect(report.hourly[0], 4);
      expect(DailyReport(history, t, true).availability, isNull);
      expect(report.insight, contains('previous recorded day'));
      final bytes = await reportPdf(report);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    },
  );
  group('Encrypted local database', () {
    late Directory dir;
    late List<int> key;
    late LocalStore store;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('kinetiq-test-');
      Hive.init(dir.path);
      key = Hive.generateSecureKey();
      store = await LocalStore.openEncrypted(key);
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    test(
      'Profile, alert and raw readings persist after database reopen; clear preserves profile',
      () async {
        final s = MotionDataService(store);
        await s.save({'name': 'Alex', 'threshold': 5});
        final controller = StreamController<String>(sync: true);
        s.connect(controller.stream);
        controller.add('HIGH');
        expect(s.latest!.alert, false);
        expect(s.latest!.reading.axes, isEmpty);
        controller.add('corrupt');
        expect(s.rejected, 1);
        final t = s.latest!.time;
        void read(int offset, Motion motion) =>
            s.ingest(Reading(motion), t.add(Duration(seconds: offset)));
        read(5, Motion.high);
        read(6, Motion.high);
        expect(s.sessionAlerts, 1);
        read(7, Motion.low);
        expect(s.latest!.alert, false);
        read(8, Motion.high);
        read(15, Motion.high);
        expect(s.latest!.alert, false);
        read(20, Motion.high);
        expect(s.sessionAlerts, 2);
        await controller.close();
        await s.flushed;
        expect(s.active, false);
        s.dispose();
        await Hive.close();
        store = await LocalStore.openEncrypted(key);
        expect((store.events.get('daily')!.values.first as Map)['alerts'], 2);
        final resumed = MotionDataService(store);
        expect(resumed.profile['name'], 'Alex');
        expect(resumed.history.length, 7);
        expect(resumed.history.where((e) => e.alertStart).length, 2);
        final files = dir.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.hive'),
        );
        for (final f in files) {
          expect(latin1.decode(await f.readAsBytes()), isNot(contains('Alex')));
        }
        await resumed.clear();
        expect(store.readEvents(), isEmpty);
        expect(store.profile['name'], 'Alex');
        resumed.dispose();
      },
    );
    test(
      'Demo and sensor streams have distinct provenance; privacy disables retention',
      () async {
        final s = MotionDataService(store)..startDemo();
        await s.flushed;
        final c = StreamController<String>(sync: true);
        s.connect(c.stream);
        c.add('LOW MOTION');
        await s.flushed;
        expect(s.history.map((e) => e.demo), [true, false]);
        await s.save({'retain': false});
        c.add('HIGH');
        await s.flushed;
        expect(s.history.length, 2);
        expect(s.latest!.reading.motion, Motion.high);
        await c.close();
        s.dispose();
      },
    );
  });
}
