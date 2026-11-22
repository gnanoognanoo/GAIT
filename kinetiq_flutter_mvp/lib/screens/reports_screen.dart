import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/analytics.dart';
import '../services/exports.dart';
import '../services/motion_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.service,
    required this.visible,
  });
  final MotionDataService service;
  final bool visible;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime date = dayOf(DateTime.now());
  bool? selectedDemo;
  static final idle = Listenable.merge(const []);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.visible ? widget.service : idle,
    builder: (context, _) {
      final s = widget.service, demo = selectedDemo ?? s.demo;
      final report = DailyReport(s.history, date, demo);
      final counts = <String, int>{};
      for (final sample in s.history.where((e) => e.demo == demo)) {
        counts.update(dayKey(sample.time), (n) => n + 1, ifAbsent: () => 1);
      }
      final recorded = counts.keys.toList()..sort((a, b) => b.compareTo(a));
      final daily = [
        for (int n = 6; n >= 0; n--)
          counts[dayKey(DateTime(date.year, date.month, date.day - n))] ?? 0,
      ];
      return DashboardPage(
        children: [
          const Eyebrow('Movement history'),
          const Text('Daily reports', style: headingStyle),
          gap,
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Wearable')),
                  ButtonSegment(value: true, label: Text('DEMO')),
                ],
                selected: {demo},
                onSelectionChanged: (v) =>
                    setState(() => selectedDemo = v.first),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(dayKey(date)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
              Builder(
                builder: (ctx) => TextButton.icon(
                  onPressed: report.samples.isEmpty
                      ? null
                      : () => perform(ctx, () async {
                          final box = ctx.findRenderObject() as RenderBox;
                          final origin =
                              box.localToGlobal(Offset.zero) & box.size;
                          await shareFile(
                            await reportPdf(report),
                            'kinetiq-${demo ? 'demo' : 'wearable'}-${dayKey(date)}.pdf',
                            'application/pdf',
                            origin,
                          );
                        }),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export PDF'),
                ),
              ),
            ],
          ),
          gap,
          SplitPanel(
            left: CardBody('Daily summary', [
              Eyebrow(demo ? 'DEMO · simulated history' : 'Wearable history'),
              gap,
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      'Observed time',
                      durationText(report.covered),
                      Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Metric(
                      'Data availability',
                      report.availability == null
                          ? '—'
                          : '${report.availability}%',
                      Icons.signal_cellular_alt,
                    ),
                  ),
                ],
              ),
              gap,
              Text(
                'Low motion   ${report.low}     ·     High motion   ${report.high}',
              ),
              const SizedBox(height: 8),
              Text('Stationary ${report.stationary} · Active ${report.active}'),
              Text('${report.movementEvents} wearable movement events'),
              LinearProgressIndicator(
                value: report.samples.isEmpty
                    ? 0
                    : report.high / report.samples.length,
                minHeight: 7,
                borderRadius: BorderRadius.circular(4),
                color: AppColors.blue,
                backgroundColor: AppColors.line,
              ),
              const SizedBox(height: 8),
              Text(
                '${report.samples.length} readings · ${report.unclassified} unclassified',
              ),
            ]),
            right: CardBody('Movement insights', [
              const Eyebrow('Rule-based daily analysis'),
              gap,
              Text(report.insight),
              gap,
              const Text(
                'Coverage uses consecutive readings within five seconds of each other during a session.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ]),
          ),
          gap,
          SplitPanel(
            left: CardBody('Hourly motion activity', [
              _Bars(report.hourly, '00:00', '23:00'),
            ]),
            right: CardBody('Seven-day trend', [
              _Bars(
                daily,
                dayKey(
                  DateTime(date.year, date.month, date.day - 6),
                ).substring(5),
                dayKey(date).substring(5),
              ),
            ]),
          ),
          gap,
          if (recorded.isNotEmpty) ...[
            CardBody('Recorded days', [
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Open a daily report'),
                value: counts.containsKey(dayKey(date)) ? dayKey(date) : null,
                items: [
                  for (final day in recorded)
                    DropdownMenuItem(
                      value: day,
                      child: Text('$day  ·  ${counts[day]} readings'),
                    ),
                ],
                onChanged: (day) {
                  if (day != null) setState(() => date = DateTime.parse(day));
                },
              ),
            ]),
            gap,
          ],
          CardBody('Alert history', [
            if (report.alerts.isEmpty)
              const Text('No alert episodes recorded for this day.'),
            for (final e in report.alerts.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.red,
                ),
                title: const Text('Sustained high motion'),
                trailing: Text(clockText(e.time)),
              ),
          ]),
        ],
      );
    },
  );
}

class _Bars extends StatelessWidget {
  const _Bars(this.counts, this.first, this.last);
  final List<int> counts;
  final String first, last;
  @override
  Widget build(BuildContext context) {
    final peak = counts.fold(0, math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          peak == 0 ? 'No recorded readings' : 'Peak · $peak readings',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final v in counts)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: '$v readings',
                      child: Container(
                        height: peak == 0 || v == 0
                            ? 1
                            : math.max(3, 84 * v / peak),
                        decoration: BoxDecoration(
                          color: v == 0 ? AppColors.line : AppColors.blue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(first), Text(last)],
        ),
      ],
    );
  }
}
