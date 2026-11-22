import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MotionChart extends StatelessWidget {
  const MotionChart({super.key, required this.values, this.height = 112});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _MotionChartPainter(values)),
    );
  }
}

class _MotionChartPainter extends CustomPainter {
  _MotionChartPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.length < 2) return;

    final points = <Offset>[];
    final usable = values.length > 30
        ? values.sublist(values.length - 30)
        : values;
    for (var i = 0; i < usable.length; i++) {
      final x = size.width * i / (usable.length - 1);
      final y =
          (size.height - (usable[i].clamp(0.0, 1.0) * (size.height * 0.82)) - 5)
              .toDouble();
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final shader = const LinearGradient(
      colors: [Color(0x553F83F7), Color(0x004FBAF2)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Offset.zero & size);
    canvas.drawPath(fill, Paint()..shader = shader);
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.blue
        ..strokeWidth = 2.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = points.last;
    canvas.drawCircle(
      last,
      5.5,
      Paint()..color = AppColors.blue.withValues(alpha: 0.15),
    );
    canvas.drawCircle(last, 3.2, Paint()..color = AppColors.blue);
  }

  @override
  bool shouldRepaint(covariant _MotionChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
