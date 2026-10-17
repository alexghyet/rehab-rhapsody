import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/surface_card.dart';

class MotionCard extends StatelessWidget {
  const MotionCard({
    super.key,
    required this.samples,
    required this.targetLow,
    required this.targetHigh,
    this.chartHeight = 150,
    this.isLive = false,
  });

  final List<double> samples;
  final double targetLow;
  final double targetHigh;
  final double chartHeight;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('Arm motion', style: AppTheme.display(18)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.mintSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLive ? 'Live' : 'Preview',
                  style: AppTheme.body(12, color: AppTheme.mintInk),
                ),
              ),
            ],
          ),
          Semantics(
            image: true,
            label: isLive
                ? 'Live arm movement compared with the target range'
                : 'Sample arm movement compared with the target range',
            child: SizedBox(
              height: chartHeight,
              child: ClipRect(
                child: CustomPaint(
                  painter: MotionChartPainter(
                    samples: samples,
                    targetLow: targetLow,
                    targetHigh: targetHigh,
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MotionChartPainter extends CustomPainter {
  MotionChartPainter({
    required List<double> samples,
    required this.targetLow,
    required this.targetHigh,
    this.textScaler = TextScaler.noScaling,
  }) : samples = List<double>.unmodifiable(samples);

  final List<double> samples;
  final double targetLow;
  final double targetHigh;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    const dotRadius = 7.0;
    const padding = dotRadius + 2;
    if (size.width <= 2 * padding || size.height <= 2 * padding) return;

    double normalized(double value, double fallback) =>
        value.isFinite ? value.clamp(0.0, 1.0) : fallback;
    double y(double value) =>
        padding + (1 - value) * (size.height - 2 * padding);

    final first = normalized(targetLow, 0.45);
    final second = normalized(targetHigh, 0.8);
    final low = first < second ? first : second;
    final high = first > second ? first : second;
    final bandTop = y(high);
    final bandHeight = y(low) - bandTop;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, bandTop, size.width, bandHeight),
        const Radius.circular(12),
      ),
      Paint()..color = AppTheme.mintSoft,
    );

    final label = TextPainter(
      text: TextSpan(
        text: 'Target',
        style: AppTheme.body(11, color: AppTheme.mintInk),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: size.width - 20);
    label.paint(
      canvas,
      Offset(
        10,
        (bandTop + (bandHeight - label.height) / 2).clamp(
          0.0,
          size.height - label.height,
        ),
      ),
    );
    label.dispose();

    final valid = samples.where((sample) => sample.isFinite).toList();
    if (valid.isEmpty) return;
    final points = [
      for (var i = 0; i < valid.length; i++)
        Offset(
          valid.length == 1
              ? size.width - padding
              : padding + (size.width - 2 * padding) * i / (valid.length - 1),
          y(normalized(valid[i], 0)),
        ),
    ];

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i == 0 ? 0 : i - 1];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
        final c1 = p1 + (p2 - p0) / 6;
        final c2 = p2 - (p3 - p1) / 6;
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
      }
      final area = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = const Color(0x1A5B3DF5));
      canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.grape
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(points.last, dotRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      points.last,
      dotRadius,
      Paint()
        ..color = AppTheme.grape
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(MotionChartPainter oldDelegate) =>
      !listEquals(oldDelegate.samples, samples) ||
      oldDelegate.targetLow != targetLow ||
      oldDelegate.targetHigh != targetHigh ||
      oldDelegate.textScaler != textScaler;
}
