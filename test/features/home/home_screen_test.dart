import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/app.dart';
import 'package:rehab_rhapsody/features/home/home_controller.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';
import 'package:rehab_rhapsody/features/home/home_screen.dart';
import 'package:rehab_rhapsody/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the bundled app fonts so phone layouts reflect the shipped UI.
    final displayFont = FontLoader('Fredoka')
      ..addFont(rootBundle.load('assets/fonts/Fredoka-600.ttf'));
    final bodyFont = FontLoader('Nunito')
      ..addFont(rootBundle.load('assets/fonts/Nunito-700.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Nunito-800.ttf'));
    await Future.wait([displayFont.load(), bodyFont.load()]);
  });

  const phones = [
    (size: Size(320, 568), top: 20.0, bottom: 0.0),
    (size: Size(375, 667), top: 20.0, bottom: 0.0),
    (size: Size(393, 852), top: 59.0, bottom: 34.0),
  ];

  for (final phone in phones) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
        'all controls fit and scroll on ${phone.size.width.toInt()} by '
        '${phone.size.height.toInt()} at ${textScale}x text',
        (tester) async {
          configurePhone(
            tester,
            size: phone.size,
            top: phone.top,
            bottom: phone.bottom,
            textScale: textScale,
          );

          await tester.pumpWidget(const RehabRhapsodyApp());
          await tester.pumpAndSettle();

          expect(find.text('Rehab Rhapsody'), findsOneWidget);
          expect(find.text('Baton offline'), findsOneWidget);
          expect(find.text('Preview'), findsOneWidget);
          expect(tester.takeException(), isNull);

          for (final label in [
            'Arm motion',
            'Instrument',
            'Piano',
            'Strings',
            'Drums',
            'Flute',
            'Mode of play',
            'Free play',
            'Guided',
            'Rhythm',
            'Volume',
            'Tempo',
          ]) {
            final control = find.text(label);
            expect(control, findsOneWidget);
            await tester.ensureVisible(control);
            await tester.pumpAndSettle();
            expect(control.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          final lastSlider = find.byType(Slider).last;
          await tester.ensureVisible(lastSlider);
          await tester.pumpAndSettle();
          expect(lastSlider.hitTestable(), findsOneWidget);
          expect(
            tester.getBottomLeft(lastSlider).dy,
            lessThanOrEqualTo(phone.size.height - phone.bottom),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('instrument, mode, volume, and tempo update the session setup', (
    tester,
  ) async {
    configurePhone(tester);
    final controller = HomeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(controller: controller),
      ),
    );

    for (final instrument in Instrument.values) {
      final option = find.text(instrument.label);
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(controller.instrument, instrument);
    }

    for (final mode in PlayMode.values) {
      final option = find.text(mode.label);
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(controller.mode, mode);
    }

    final sliders = find.byType(Slider);
    final initialVolume = controller.volume;
    await tester.ensureVisible(sliders.first);
    await tester.drag(sliders.first, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(controller.volume, lessThan(initialVolume));
    expect(find.text('${controller.volume.round()}%'), findsOneWidget);

    final initialTempo = controller.tempo;
    await tester.ensureVisible(sliders.last);
    await tester.drag(sliders.last, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(controller.tempo, greaterThan(initialTempo));
    expect(find.text('${controller.tempo.round()} BPM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session action starts, pauses, and resumes elapsed time', (
    tester,
  ) async {
    configurePhone(tester);
    final semantics = tester.ensureSemantics();
    final controller = HomeController();
    addTearDown(controller.dispose);
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(controller: controller),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Start session'));
      await tester.pump(const Duration(seconds: 3));
      expect(controller.isRunning, isTrue);
      expect(find.text('00:00:03'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Pause session'));
      await tester.pump(const Duration(seconds: 4));
      expect(controller.isRunning, isFalse);
      expect(find.text('00:00:03'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Start session'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:00:05'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Pause session'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    } finally {
      controller.pauseSession();
      semantics.dispose();
    }
  });

  testWidgets('sliders announce values and respond to accessibility actions', (
    tester,
  ) async {
    configurePhone(tester);
    final semantics = tester.ensureSemantics();
    final controller = HomeController();
    addTearDown(controller.dispose);
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(controller: controller),
        ),
      );

      for (final slider in [
        (label: 'Volume', value: () => controller.volume, unit: '%'),
        (label: 'Tempo', value: () => controller.tempo, unit: ' BPM'),
      ]) {
        final control = find.byWidgetPredicate(
          (widget) => widget is Slider && widget.label == slider.label,
        );
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();

        final semanticControl = find.bySemanticsLabel(slider.label);
        var node = tester.getSemantics(semanticControl);
        final initial = node.getSemanticsData();
        final initialValue = slider.value();
        expect(initial.label, slider.label);
        expect(initial.value, '${initialValue.round()}${slider.unit}');
        expect(initial.increasedValue, isNot(initial.value));
        expect(initial.decreasedValue, isNot(initial.value));
        expect(initial.increasedValue, isNot(initial.decreasedValue));
        expect(initial.increasedValue, endsWith(slider.unit));
        expect(initial.decreasedValue, endsWith(slider.unit));
        expect(initial.hasAction(ui.SemanticsAction.increase), isTrue);
        expect(initial.hasAction(ui.SemanticsAction.decrease), isTrue);

        node.owner!.performAction(node.id, ui.SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(slider.value(), greaterThan(initialValue));
        node = tester.getSemantics(semanticControl);
        final increased = node.getSemanticsData();
        expect(increased.value, initial.increasedValue);
        expect(increased.value, '${slider.value().round()}${slider.unit}');

        node.owner!.performAction(node.id, ui.SemanticsAction.decrease);
        await tester.pumpAndSettle();
        expect(slider.value(), closeTo(initialValue, 0.000001));
        final decreased = tester
            .getSemantics(semanticControl)
            .getSemanticsData();
        expect(decreased.value, increased.decreasedValue);
        expect(decreased.value, '${slider.value().round()}${slider.unit}');
      }
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('backgrounding pauses the session until the user resumes it', (
    tester,
  ) async {
    configurePhone(tester);
    final controller = HomeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(controller: controller),
      ),
    );
    controller.toggleSession();
    await tester.pump(const Duration(seconds: 2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(controller.isRunning, isFalse);
    expect(controller.elapsed, const Duration(seconds: 2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.isRunning, isFalse);
    expect(controller.elapsed, const Duration(seconds: 2));

    controller.toggleSession();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.elapsed, const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.pauseSession();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void configurePhone(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  double top = 59,
  double bottom = 34,
  double textScale = 1,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
