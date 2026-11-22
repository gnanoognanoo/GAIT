import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetiq_motion/screens/app_shell.dart';
import 'package:kinetiq_motion/services/local_store.dart';
import 'package:kinetiq_motion/services/motion_data_service.dart';
import 'package:kinetiq_motion/models/motion_sample.dart';
import 'package:kinetiq_motion/theme/app_theme.dart';

class VolatileStore implements LocalStore {
  final rows = <MotionSample>[];
  @override
  Map<String, dynamic> profile = {'retain': false};
  @override
  List<MotionSample> readEvents() => rows.toList();
  @override
  Future<void> appendBatch(List<MotionSample> samples) async {
    rows.addAll(samples);
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> p) async {
    profile = p;
  }

  @override
  Future<void> clearHistory() async {
    rows.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [360.0, 1024.0]) {
    testWidgets('Navigation, profile and demo at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MotionDataService(VolatileStore());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AppShell(service: service, showModel: false),
        ),
      );
      expect(find.text('Wearable disconnected'.toUpperCase()), findsOneWidget);
      await tester.ensureVisible(find.text('Start demo'));
      await tester.tap(find.text('Start demo'));
      await tester.pump();
      expect(service.latest!.demo, true);
      expect(find.text('LOW MOTION'), findsWidgets);
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('Daily reports'), findsOneWidget);
      await tester.tap(find.text('Wearable'));
      await tester.pump();
      expect(
        find.text('No readings were recorded on this day.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Alex');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(service.profile['name'], 'Alex');
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(service.active, true);
      await tester.ensureVisible(find.text('End session'));
      await tester.tap(find.text('End session'));
      await tester.pump();
      expect(service.active, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
