import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/motion_sample.dart';
import 'analytics.dart';

class LocalStore {
  LocalStore(this.events, this.settings) {
    for (final key in events.keys.whereType<int>()) {
      if (key >= _nextId) _nextId = key + 1;
    }
  }
  int _nextId = 0;
  final Box<Map> events, settings;

  static Future<LocalStore> open() async {
    if (!kIsWeb) Hive.init((await getApplicationSupportDirectory()).path);
    const vault = FlutterSecureStorage();
    var key = await vault.read(key: 'kinetiq.database.v1');
    if (key == null) {
      if (await Hive.boxExists('motion_v1')) {
        throw StateError('Database key unavailable');
      }
      key = base64UrlEncode(Hive.generateSecureKey());
      await vault.write(key: 'kinetiq.database.v1', value: key);
    }
    return openEncrypted(base64Url.decode(key));
  }

  static Future<LocalStore> openEncrypted(List<int> key) async {
    Future<Box<Map>> box(String name) =>
        Hive.openBox<Map>(name, encryptionCipher: HiveAesCipher(key));
    return LocalStore(await box('motion_v1'), await box('settings_v1'));
  }

  List<MotionSample> readEvents() => events.keys
      .whereType<int>()
      .map((id) => MotionSample.fromMap(events.get(id)!))
      .toList();
  Map<String, dynamic> get profile =>
      Map<String, dynamic>.from(settings.get('profile') ?? {});
  Future<void> appendBatch(List<MotionSample> batch) async {
    // Store the reading and its day/source totals in the same box transaction.
    final summaries = Map<String, dynamic>.from(events.get('daily') ?? {});
    final records = <dynamic, Map>{};
    for (final s in batch) {
      final key = dayKey(s.time) + (s.demo ? '/demo' : '/wearable');
      final day = Map<String, int>.from(summaries[key] as Map? ?? {});
      for (final metric in [
        'total',
        s.reading.motion.name,
        if (s.alertStart) 'alerts',
      ]) {
        day.update(metric, (n) => n + 1, ifAbsent: () => 1);
      }
      summaries[key] = day;
      records[_nextId++] = s.toMap();
    }
    await events.putAll({...records, 'daily': summaries});
  }

  Future<void> saveProfile(Map<String, dynamic> profile) =>
      settings.put('profile', profile);
  Future<void> clearHistory() async {
    await events.clear();
  }
}
