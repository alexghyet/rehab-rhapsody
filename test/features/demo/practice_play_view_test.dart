import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/baton/baton_transport.dart';
import 'package:rehab_rhapsody/features/demo/demo_controller.dart';
import 'package:rehab_rhapsody/features/demo/practice_play_view.dart';
import 'package:rehab_rhapsody/features/home/home_controller.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';
import 'package:rehab_rhapsody/features/music/music_note.dart';
import 'package:rehab_rhapsody/theme/app_theme.dart';

import '../../support/load_test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  for (final mode in [PlayMode.free, PlayMode.guided, PlayMode.rhythm]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${mode.label} fits a short iPhone workspace at ${scale}x text without scrolling',
        (tester) async {
          final h = _Harness(mode);
          await _pump(tester, h, scale: scale);
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
          final workspace = tester.getRect(find.byType(PracticePlayView));
          for (final midi in demoMidiNotes) {
            final pad = find.byKey(ValueKey('practice-note-$midi'));
            expect(pad.hitTestable(), findsOneWidget);
            final bounds = tester.getRect(pad);
            expect(bounds.width, greaterThanOrEqualTo(44));
            expect(bounds.height, greaterThanOrEqualTo(44));
            expect(workspace.contains(bounds.topLeft), isTrue);
            expect(
              workspace.contains(bounds.bottomRight - const Offset(0.1, 0.1)),
              isTrue,
            );
          }
          for (final key in ['practice-toggle', 'practice-reset']) {
            final control = find.byKey(Key(key));
            expect(control.hitTestable(), findsOneWidget);
            expect(
              tester.getSize(control).shortestSide,
              greaterThanOrEqualTo(44),
            );
          }
          expect(
            tester
                .getSize(find.byKey(const Key('practice-motion-chart')))
                .height,
            greaterThan(30),
          );
          h.dispose();
          await tester.pump();
        },
      );
    }
  }

  testWidgets('pads play through the demo and confirmed notes clear on pause', (
    tester,
  ) async {
    final h = _Harness(PlayMode.free);
    final semantics = tester.ensureSemantics();
    await _pump(tester, h);
    await tester.tap(find.byKey(const ValueKey('practice-note-64')));
    await tester.pump();
    expect(h.audio.notes, [64]);
    expect(h.home.currentNote, MusicNote(64));
    expect(find.bySemanticsLabel('Current note E, octave 4'), findsOneWidget);
    expect(find.bySemanticsLabel('Pause session'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-toggle')));
    await tester.pump();
    expect(h.home.isRunning, isFalse);
    expect(h.home.currentNote, isNull);
    expect(
      find.bySemanticsLabel('Current note, no note playing'),
      findsOneWidget,
    );
    h.dispose();
    semantics.dispose();
    await tester.pump();
  });

  testWidgets('Guided preserves requested-pitch gating and advances its cue', (
    tester,
  ) async {
    final h = _Harness(PlayMode.guided);
    await _pump(tester, h);
    expect(find.text('Next: C4 · Step 1 of 14'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-note-62')));
    await tester.pump();
    expect(h.audio.notes, isEmpty);
    expect(h.demo.guidedStep, 0);
    await tester.tap(find.byKey(const ValueKey('practice-note-60')));
    await tester.pump();
    expect(h.audio.notes, [60]);
    expect(find.text('Next: C4 · Step 2 of 14'), findsOneWidget);
    h.dispose();
    await tester.pump();
  });

  testWidgets(
    'current pitches retain their octave and accessible sharp names',
    (tester) async {
      final h = _Harness(PlayMode.free);
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await _pump(tester, h, scale: 2);
      expect(
        find.bySemanticsLabel('Current note, no note playing'),
        findsOneWidget,
      );
      h.home.toggleSession();
      for (final midi in [0, 60, 61, 66, 127]) {
        final note = MusicNote(midi);
        h.home.noteStarted(
          note: note,
          sessionId: h.home.playbackSessionId,
          voiceId: midi,
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel('Current note ${note.spokenLabel}'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('practice-current-note')),
            matching: find.text(note.displayLabel),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      h.home.pauseSession();
      await tester.pump();
      expect(
        find.bySemanticsLabel('Current note, no note playing'),
        findsOneWidget,
      );
      h.dispose();
      await tester.pump();
    },
  );

  testWidgets('session time and reset work without opening another surface', (
    tester,
  ) async {
    final h = _Harness(PlayMode.rhythm);
    await _pump(tester, h);
    expect(find.text('Beat 1 · 90 BPM'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-toggle')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(h.home.elapsed, const Duration(seconds: 2));
    expect(find.text('00:00:02'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-reset')));
    await tester.pump();
    expect(h.home.isRunning, isFalse);
    expect(h.home.elapsed, Duration.zero);
    expect(find.text('00:00:00'), findsOneWidget);
    h.dispose();
    await tester.pump();
  });
}

Future<void> _pump(WidgetTester tester, _Harness h, {double scale = 1}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 350,
              child: PracticePlayView(
                home: h.home,
                demo: h.demo,
                samples: const [0.2, 0.6, 0.7, 0.5],
                motionIsLive: false,
                targetLow: 0.6,
                targetHigh: 0.7,
              ),
            ),
          ),
        ),
      ),
    );

class _Harness {
  _Harness(PlayMode mode) {
    home.selectMode(mode);
    demo = DemoController(home: home, transport: _Baton(), audio: audio);
  }
  final home = HomeController();
  final audio = _Audio();
  late final DemoController demo;
  void dispose() {
    demo.dispose();
    home.dispose();
  }
}

class _Audio extends DemoAudioEngine {
  final notes = <int>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<void> play({
    required int midiNote,
    required Instrument instrument,
    required double volume,
  }) async {
    notes.add(midiNote);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _Baton implements BatonTransport {
  @override
  BatonConnection get connection =>
      const BatonConnection(status: BatonConnectionStatus.idle);
  @override
  Stream<BatonConnection> get connections => const Stream.empty();
  @override
  Stream<List<int>> get packets => const Stream.empty();
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {}
}
