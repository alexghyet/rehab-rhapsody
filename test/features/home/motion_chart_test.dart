import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/home/widgets/motion_chart.dart';

void main() {
  testWidgets('tiny charts and oversized labels do not throw while painting', (
    tester,
  ) async {
    for (final size in [
      Size.zero,
      const Size(19, 30),
      const Size(60, 20),
      const Size(300, 160),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.fromSize(
              size: size,
              child: CustomPaint(
                painter: MotionChartPainter(
                  samples: const [0.1, double.nan, 0.65, 0.8],
                  targetLow: 0.6,
                  targetHigh: 0.7,
                  textScaler: const TextScaler.linear(4),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
