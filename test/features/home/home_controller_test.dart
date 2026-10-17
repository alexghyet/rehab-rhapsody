import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/home/home_controller.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';

void main() {
  test('a session starts with the advertised setup and no elapsed time', () {
    final controller = HomeController();
    addTearDown(controller.dispose);

    expect(controller.instrument, Instrument.piano);
    expect(controller.mode, PlayMode.free);
    expect(controller.volume, 65);
    expect(controller.tempo, 90);
    expect(controller.elapsed, Duration.zero);
    expect(controller.formattedTime, '00:00:00');
    expect(controller.isRunning, isFalse);
  });

  test('setup changes notify the screen and preserve the other choices', () {
    final controller = HomeController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.selectInstrument(Instrument.flute);
    controller.selectMode(PlayMode.guided);
    controller.setVolume(35);
    controller.setTempo(120);

    expect(controller.instrument, Instrument.flute);
    expect(controller.mode, PlayMode.guided);
    expect(controller.volume, 35);
    expect(controller.tempo, 120);
    expect(controller.isRunning, isFalse);
    expect(notifications, 4);
  });

  testWidgets('pausing freezes time and resuming continues the same session', (
    tester,
  ) async {
    final controller = HomeController();
    addTearDown(controller.dispose);

    controller.toggleSession();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.isRunning, isTrue);
    expect(controller.elapsed, const Duration(seconds: 3));
    expect(controller.formattedTime, '00:00:03');

    controller.pauseSession();
    await tester.pump(const Duration(seconds: 5));
    expect(controller.isRunning, isFalse);
    expect(controller.elapsed, const Duration(seconds: 3));

    controller.toggleSession();
    await tester.pump(const Duration(seconds: 2));
    expect(controller.elapsed, const Duration(seconds: 5));

    controller.toggleSession();
    await tester.pump(const Duration(seconds: 2));
    expect(controller.isRunning, isFalse);
    expect(controller.formattedTime, '00:00:05');
  });

  testWidgets('session time rolls over minutes and hours', (tester) async {
    final controller = HomeController();
    addTearDown(controller.dispose);

    try {
      controller.toggleSession();
      await tester.pump(const Duration(seconds: 3661));

      expect(
        controller.elapsed,
        const Duration(hours: 1, minutes: 1, seconds: 1),
      );
      expect(controller.formattedTime, '01:01:01');
    } finally {
      controller.pauseSession();
    }
  });

  testWidgets('disposing a running session cancels future timer updates', (
    tester,
  ) async {
    final controller = HomeController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.toggleSession();
    await tester.pump(const Duration(seconds: 1));
    final elapsedBeforeDispose = controller.elapsed;
    final notificationsBeforeDispose = notifications;

    controller.dispose();
    await tester.pump(const Duration(seconds: 5));

    expect(controller.elapsed, elapsedBeforeDispose);
    expect(notifications, notificationsBeforeDispose);
    expect(tester.takeException(), isNull);
  });
}
