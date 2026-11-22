import 'package:flutter/material.dart';
import '../models/motion_sample.dart';
import '../services/analytics.dart';
import '../services/motion_data_service.dart';
import '../services/serial.dart';
import '../services/ble_transport.dart';
import '../widgets/device_picker.dart';
import 'package:universal_ble/universal_ble.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard.dart';
import '../widgets/glass_panel.dart';
import '../widgets/leg_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.service,
    this.showModel = true,
    this.visible = true,
  });
  final MotionDataService service;
  final bool showModel, visible;
  Future<void> connect(BuildContext context) async {
    String value = '';
    final baud = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('USB serial input'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select the baud rate used by your firmware. The reader accepts newline-delimited motion data.',
              ),
              TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Baud rate'),
                onChanged: (v) => update(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (int.tryParse(value) ?? 0) > 0
                  ? () => Navigator.pop(ctx, int.parse(value))
                  : null,
              child: const Text('Select port'),
            ),
          ],
        ),
      ),
    );
    if (baud == null || !context.mounted) return;
    await perform(context, () async {
      final lines = await openSerial(baud);
      service.connect(lines);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final s = service,
          sample = s.latest,
          alert = sample?.alert == true,
          motion = sample?.reading.motion;
      final state = motion == null
          ? 'Awaiting data'
          : motion == Motion.unknown
          ? 'Unclassified'
          : motion.display;
      final hour = DateTime.now().hour;
      final name = (s.profile['name'] as String? ?? '').trim().split(' ').first;
      return DashboardPage(
        children: [
          Eyebrow(
            'Good ${hour < 12
                ? 'morning'
                : hour < 17
                ? 'afternoon'
                : 'evening'}${name.isEmpty ? '' : ', $name'}',
          ),
          const Text('Motion overview', style: headingStyle),
          gap,
          SplitPanel(
            left: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xffe4f4ff),
                    Color(0xffc4dfef),
                    Color(0xffeaf4ff),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          const Expanded(child: Eyebrow('Movement model')),
                          StatusTag(
                            label: alert
                                ? 'ALERT'
                                : s.active
                                ? (s.demo ? 'DEMO' : 'LIVE')
                                : 'OFFLINE',
                            alert: alert,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).width < 500
                          ? 258
                          : 330,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _Grid()),
                          if (showModel)
                            LegView(
                              high:
                                  visible &&
                                  (motion == Motion.high ||
                                      motion == Motion.active),
                              alert: alert,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Icon(
                            Icons.threed_rotation_outlined,
                            size: 16,
                            color: alert ? AppColors.red : AppColors.blueDeep,
                          ),
                          Text(
                            alert
                                ? 'Knee alert · sustained high motion'
                                : 'Drag to rotate · pinch or scroll to zoom',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            right: CardBody('Monitoring session', [
              Eyebrow(
                s.active
                    ? (s.demo ? 'DEMO · simulated readings' : s.linkLabel)
                    : 'Wearable disconnected',
              ),
              if (s.wearable?.health case final h?) ...[
                Text(
                  'I/O ${h.counters[0]} · Invalid ${h.counters[1]} · Timing ${h.counters[2]} · TX ${h.counters[3]}',
                ),
              ],
              if (s.wearable case final link?)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: link.ready
                          ? () => perform(
                              context,
                              () => link.command(
                                link.streaming
                                    ? WearableCommand.stop
                                    : WearableCommand.start,
                              ),
                            )
                          : null,
                      child: Text(
                        link.streaming ? 'Pause stream' : 'Resume stream',
                      ),
                    ),
                    TextButton(
                      onPressed: link.ready
                          ? () => perform(
                              context,
                              () => link.command(WearableCommand.calibrate),
                            )
                          : null,
                      child: const Text('Calibrate wearable'),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (sample?.reading.intensity != null)
                Text('Movement intensity · ${sample!.reading.intensity}%'),
              Text(
                state,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      'Monitored',
                      durationText(s.monitored),
                      Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Metric(
                      'Alert episodes',
                      '${s.sessionAlerts}',
                      Icons.notifications_none,
                    ),
                  ),
                ],
              ),
              gap,
              if (s.active)
                OutlinedButton.icon(
                  onPressed: s.stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End session'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: s.startDemo,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start demo'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Connect wearable'),
                  onPressed: () async {
                    final device = await showDialog<BleDevice>(
                      context: context,
                      builder: (_) => const DevicePicker(),
                    );
                    if (device == null || !context.mounted) return;
                    s.connectWearable(device.deviceId);
                    await perform(
                      context,
                      () => s.save({
                        ...s.profile,
                        'deviceId': device.deviceId,
                        'device': device.name ?? 'KINETIQ',
                      }),
                    );
                  },
                ),
                if (serialSupported)
                  TextButton.icon(
                    onPressed: () => connect(context),
                    icon: const Icon(Icons.usb),
                    label: const Text('Connect USB device'),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                s.active
                    ? (s.retain
                          ? 'Session history is saved on this device.'
                          : 'History is off for new readings.')
                    : 'Demo sessions are stored in a separate report history.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (s.error != null)
                Text(s.error!, style: const TextStyle(color: AppColors.red)),
            ]),
          ),
          gap,
          SplitPanel(
            left: CardBody('Sensor readings', [
              if (sample?.reading.quaternion case final q?) ...[
                const Eyebrow('Measured sensor orientation'),
                Text(
                  ['Roll', 'Pitch', 'Relative yaw'].indexed
                      .map(
                        (e) =>
                            '${e.$2} ${sensorEuler(q)[e.$1].toStringAsFixed(1)}°',
                      )
                      .join(' · '),
                ),
                const SizedBox(height: 12),
              ],
              for (final pair in [
                ('Accelerometer', 'a', 'g'),
                ('Gyroscope', 'g', '°/s'),
              ]) ...[
                Eyebrow('${pair.$1} · ${pair.$3}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final axis in ['x', 'y', 'z'])
                      Expanded(
                        child: Text(
                          '${axis.toUpperCase()}   ${sample?.reading.axes[pair.$2 + axis]?.toStringAsFixed(2) ?? '—'}',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                sample?.reading.axes.isNotEmpty == true
                    ? 'Model flexion illustrates the motion state.'
                    : 'Axis measurements are unavailable.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (s.wearable == null &&
                  sample != null &&
                  Reading.axisNames.every(sample.reading.axes.containsKey))
                TextButton(
                  onPressed: s.orientation.collecting
                      ? null
                      : s.orientation.begin,
                  child: Text(
                    s.orientation.collecting
                        ? 'Hold still · calibrating'
                        : s.orientation.relative != null
                        ? 'Relative roll ${s.orientation.relative!.toStringAsFixed(1)}° · recalibrate'
                        : 'Calibrate sensor roll',
                  ),
                ),
            ]),
            right: CardBody('Session timeline', [
              if (s.recent.isEmpty)
                const Text('Motion changes will appear here during a session.'),
              for (final e in s.recent.take(4))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.alert
                        ? Icons.notifications_active_outlined
                        : Icons.timeline,
                    color: e.alert ? AppColors.red : AppColors.blue,
                  ),
                  title: Text(
                    '${e.demo ? 'DEMO · ' : ''}${e.alertStart ? 'Alert started' : e.reading.motion.name.toUpperCase()}',
                  ),
                  trailing: Text(clockText(e.time)),
                ),
              if (s.rejected > 0) Text('${s.rejected} unrecognized lines'),
            ]),
          ),
        ],
      );
    },
  );
}

class _Grid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x1983a8cd)
      ..strokeWidth = .7;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    final c = Offset(size.width / 2, size.height * .51);
    p
      ..style = PaintingStyle.stroke
      ..color = const Color(0x4081a8cd);
    for (final r in [.34, .44]) {
      canvas.drawCircle(c, size.shortestSide * r, p);
    }
  }

  @override
  bool shouldRepaint(_Grid old) => false;
}
