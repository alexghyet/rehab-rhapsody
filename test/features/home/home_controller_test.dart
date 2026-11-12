import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/home/home_controller.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';
import 'package:rehab_rhapsody/features/music/music_note.dart';

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
    expect(controller.canReset, isFalse);
    expect(controller.currentNote, isNull);
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

  testWidgets('reset clears a paused timer and preserves the music setup', (
    tester,
  ) async {
    final controller = HomeController();
    addTearDown(controller.dispose);
    controller.selectInstrument(Instrument.flute);
    controller.selectMode(PlayMode.guided);
    controller.setVolume(35);
    controller.setTempo(120);
    controller.toggleSession();
    await tester.pump(const Duration(seconds: 3));

    controller.resetSession();
    expect(controller.isRunning, isTrue);
    expect(controller.elapsed, const Duration(seconds: 3));
    expect(controller.canReset, isFalse);

    controller.pauseSession();
    expect(controller.canReset, isTrue);
    controller.resetSession();
    await tester.pump(const Duration(seconds: 2));
    expect(controller.formattedTime, '00:00:00');
    expect(controller.isRunning, isFalse);
    expect(controller.canReset, isFalse);
    expect(controller.instrument, Instrument.flute);
    expect(controller.mode, PlayMode.guided);
    expect(controller.volume, 35);
    expect(controller.tempo, 120);

    controller.toggleSession();
    try {
      await tester.pump(const Duration(seconds: 1));
      expect(controller.formattedTime, '00:00:01');
    } finally {
      controller.pauseSession();
    }
  });

  test('pausing before the first timer tick still allows a reset', () {
    final controller = HomeController();
    addTearDown(controller.dispose);
    controller.toggleSession();
    controller.pauseSession();
    expect(controller.elapsed, Duration.zero);
    expect(controller.canReset, isTrue);
    controller.resetSession();
    expect(controller.canReset, isFalse);
  });

  test('playback feedback tracks overlapping voices and repeated pitches', () {
    final controller = HomeController();
    addTearDown(controller.dispose);
    controller.toggleSession();
    final sessionId = controller.playbackSessionId;
    final c4 = MusicNote(60);
    final g4 = MusicNote(67);

    controller.noteStarted(note: c4, sessionId: sessionId, voiceId: 1);
    expect(controller.currentNote, c4);
    controller.noteStarted(note: g4, sessionId: sessionId, voiceId: 2);
    expect(controller.currentNote, g4);
    controller.noteStopped(sessionId: sessionId, voiceId: 2);
    expect(controller.currentNote, c4);

    controller.noteStarted(note: c4, sessionId: sessionId, voiceId: 3);
    controller.noteStopped(sessionId: sessionId, voiceId: 1);
    expect(controller.currentNote, c4);
    controller.noteStopped(sessionId: sessionId, voiceId: 3);
    expect(controller.currentNote, isNull);
  });

  test('pause and reset reject late feedback from an earlier session', () {
    final controller = HomeController();
    addTearDown(controller.dispose);
    final c4 = MusicNote(60);
    controller.toggleSession();
    final previousSessionId = controller.playbackSessionId;
    controller.noteStarted(note: c4, sessionId: previousSessionId, voiceId: 1);

    controller.pauseSession();
    expect(controller.currentNote, isNull);
    controller.noteStarted(note: c4, sessionId: previousSessionId, voiceId: 2);
    expect(controller.currentNote, isNull);
    controller.resetSession();
    controller.toggleSession();
    final currentSessionId = controller.playbackSessionId;
    expect(currentSessionId, isNot(previousSessionId));

    controller.noteStarted(note: c4, sessionId: previousSessionId, voiceId: 1);
    expect(controller.currentNote, isNull);
    controller.noteStarted(note: c4, sessionId: currentSessionId, voiceId: 1);
    controller.noteStopped(sessionId: previousSessionId, voiceId: 1);
    expect(controller.currentNote, c4);
    controller.noteStopped(sessionId: currentSessionId, voiceId: 1);
    expect(controller.currentNote, isNull);
  });

  test('duplicate starts and unknown stops do not alter the active note', () {
    final controller = HomeController();
    addTearDown(controller.dispose);
    controller.toggleSession();
    final sessionId = controller.playbackSessionId;
    controller.noteStarted(
      note: MusicNote(60),
      sessionId: sessionId,
      voiceId: 1,
    );
    controller.noteStarted(
      note: MusicNote(67),
      sessionId: sessionId,
      voiceId: 2,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.noteStarted(
      note: MusicNote(60),
      sessionId: sessionId,
      voiceId: 1,
    );
    controller.noteStopped(sessionId: sessionId, voiceId: 99);
    expect(controller.currentNote, MusicNote(67));
    expect(notifications, 0);
  });

  testWidgets('disposing a running session cancels future timer updates', (
    tester,
  ) async {
    final controller = HomeController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.toggleSession();
    final sessionId = controller.playbackSessionId;
    controller.noteStarted(
      note: MusicNote(60),
      sessionId: sessionId,
      voiceId: 1,
    );
    await tester.pump(const Duration(seconds: 1));
    final elapsedBeforeDispose = controller.elapsed;
    final notificationsBeforeDispose = notifications;

    controller.dispose();
    expect(controller.isRunning, isFalse);
    expect(controller.currentNote, isNull);
    controller.noteStarted(
      note: MusicNote(67),
      sessionId: sessionId,
      voiceId: 2,
    );
    controller.noteStopped(sessionId: sessionId, voiceId: 1);
    await tester.pump(const Duration(seconds: 5));

    expect(controller.elapsed, elapsedBeforeDispose);
    expect(notifications, notificationsBeforeDispose);
    expect(tester.takeException(), isNull);
  });
}
