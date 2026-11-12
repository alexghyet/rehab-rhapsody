import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/demo/motion_target_indicator.dart';

void main() {
  testWidgets(
    'live indicator guides higher and lower, including target edges',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      for (final reading in [
        (level: 0.59, status: 'Higher'),
        (level: 0.71, status: 'Lower'),
        (level: 0.6, status: 'In target'),
        (level: 0.65, status: 'In target'),
        (level: 0.7, status: 'In target'),
      ]) {
        await _pumpIndicator(tester, level: reading.level);
        expect(
          find.bySemanticsLabel('Live movement target. ${reading.status}.'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('missing, invalid and stale readings never appear in target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    for (final reading in [
      (level: 0.65, live: false),
      (level: null, live: true),
      (level: double.nan, live: true),
      (level: double.infinity, live: true),
    ]) {
      await _pumpIndicator(tester, level: reading.level, live: reading.live);
      expect(
        find.bySemanticsLabel('Live movement target. Waiting for baton.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Live movement target. In target.'),
        findsNothing,
      );
    }
  });

  testWidgets('collapsed target indicators paint without invalid geometry', (
    tester,
  ) async {
    for (final size in [Size.zero, const Size(26, 10), const Size(26, 248)]) {
      await _pumpIndicator(tester, size: size);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pumpIndicator(
  WidgetTester tester, {
  double? level = 0.65,
  bool live = true,
  Size size = const Size(26, 248),
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox.fromSize(
          size: size,
          child: MotionTargetIndicator(
            targetLow: 0.6,
            targetHigh: 0.7,
            currentLevel: level,
            isLive: live,
          ),
        ),
      ),
    ),
  ),
);
