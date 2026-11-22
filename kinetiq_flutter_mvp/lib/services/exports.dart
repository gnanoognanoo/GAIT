import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'share_native.dart' if (dart.library.js_interop) 'share_web.dart';
export 'share_native.dart' if (dart.library.js_interop) 'share_web.dart';
import '../brand.dart';
import '../models/motion_sample.dart';
import 'analytics.dart';

Future<Uint8List> reportPdf(DailyReport report) async {
  final pdf = pw.Document(title: '$productName daily movement report');
  const blue = PdfColor.fromInt(0xff2864e8);
  pdf.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text(
          productName,
          style: pw.TextStyle(
            color: blue,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Header(level: 0, text: 'Daily movement report'),
        pw.Text(
          '${dayKey(report.date)}  |  ${report.demo ? 'DEMO - simulated readings' : 'Wearable readings'}',
        ),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: ['Measure', 'Result'],
          data: [
            ['Samples', '${report.samples.length}'],
            [
              'Stationary / low / active / high / unclassified',
              '${report.stationary} / ${report.low} / ${report.active} / ${report.high} / ${report.unclassified}',
            ],
            ['Observed duration', durationText(report.covered)],
            [
              'Within-session coverage',
              report.availability == null
                  ? 'Unavailable'
                  : '${report.availability}%',
            ],
            ['Alert onsets', '${report.alerts.length}'],
            ['Wearable movement events', '${report.movementEvents}'],
          ],
        ),
        pw.Header(level: 1, text: 'Movement insights'),
        pw.Paragraph(text: report.insight),
        pw.Paragraph(
          text:
              'Coverage counts intervals of up to five seconds between readings in the same session. An isolated reading has no measurable duration.',
        ),
        if (report.samples.isNotEmpty) ...[
          pw.Header(level: 1, text: 'Hourly readings'),
          pw.Text(
            [
              for (int h = 0; h < 24; h++)
                if (report.hourly[h] > 0)
                  '${h.toString().padLeft(2, '0')}:00  (${report.hourly[h]})',
            ].join('     '),
          ),
        ],
        if (report.alerts.isNotEmpty) ...[
          pw.Header(level: 1, text: 'Alert history'),
          for (final s in report.alerts)
            pw.Text('${clockText(s.time)}  Sustained high motion'),
        ],
      ],
    ),
  );
  return pdf.save();
}

Future<void> exportHistory(List<MotionSample> history, Rect origin) =>
    shareFile(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'version': 1,
            'readings': history.map((s) => s.toMap()).toList(),
          }),
        ),
      ),
      'kinetiq-history.json',
      'application/json',
      origin,
    );
