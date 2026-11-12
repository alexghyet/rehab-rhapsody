import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/demo/motion_target_indicator.dart';
import 'package:rehab_rhapsody/features/songs/song.dart';
import 'package:rehab_rhapsody/features/songs/song_game.dart';
import 'package:rehab_rhapsody/features/songs/song_play_card.dart';
import 'package:rehab_rhapsody/theme/app_theme.dart';

import '../../support/load_test_fonts.dart';

const _firstSong = SongDefinition(
  id: 'first',
  title: 'A familiar melody',
  subtitle: 'A gentle place to start',
  composer: 'Traditional',
  bpm: 80,
  notes: [
    SongNote(
      id: 0,
      midiNote: 64,
      lane: 2,
      at: Duration(seconds: 3),
      duration: Duration(milliseconds: 750),
    ),
    SongNote(
      id: 1,
      midiNote: 60,
      lane: 0,
      at: Duration(seconds: 4),
      duration: Duration(milliseconds: 750),
    ),
  ],
  duration: Duration(seconds: 6),
  backingAsset: 'audio/songs/first.wav',
);

const _secondSong = SongDefinition(
  id: 'second',
  title: 'Another melody',
  subtitle: 'Another familiar tune',
  composer: 'Traditional',
  bpm: 84,
  notes: [],
  duration: Duration(seconds: 8),
  backingAsset: 'audio/songs/second.wav',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  for (final height in [350.0, 420.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'song stage fits 300 by $height at $scale text scale without scrolling',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          await _pumpCard(
            tester,
            height: height,
            scale: scale,
            targetIndicator: const MotionTargetIndicator(
              targetLow: 0.6,
              targetHigh: 0.7,
              currentLevel: 0.65,
              isLive: true,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          expect(
            find.byKey(const Key('song-chooser')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('song-toggle')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('song-restart')).hitTestable(),
            findsOneWidget,
          );
          final playRect = tester.getRect(
            find.byKey(const Key('song-play-note')),
          );
          for (final key in ['song-chooser', 'song-toggle', 'song-restart']) {
            final size = tester.getSize(find.byKey(Key(key)));
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
          }
          expect(playRect.width, greaterThanOrEqualTo(44));
          expect(playRect.height, greaterThanOrEqualTo(44));
          final highway = find.byKey(const Key('song-highway'));
          final cardBounds = tester.getRect(find.byType(SongPlayCard));
          final highwayBounds = tester.getRect(highway);
          expect(cardBounds.contains(highwayBounds.topLeft), isTrue);
          expect(cardBounds.contains(highwayBounds.bottomRight), isTrue);
          expect(tester.getSize(highway).height, greaterThan(80));
          final indicator = find.byType(MotionTargetIndicator);
          final indicatorBounds = tester.getRect(indicator);
          expect(cardBounds.contains(indicatorBounds.topLeft), isTrue);
          expect(cardBounds.contains(indicatorBounds.bottomRight), isTrue);
          expect(
            tester.getSize(indicator).height,
            tester.getSize(highway).height,
          );
          expect(tester.getSize(indicator).width, 26);
          expect(find.bySemanticsLabel('Start song'), findsOneWidget);
          expect(find.bySemanticsLabel('Restart'), findsOneWidget);
          expect(find.bySemanticsLabel('Score 0'), findsOneWidget);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets(
    'timing pad is disabled before start and accepts one tap while playing',
    (tester) async {
      var notes = 0;
      var toggles = 0;
      await _pumpCard(
        tester,
        onPlayNote: () => notes++,
        onToggle: () => toggles++,
      );
      final noteButton = find.byKey(const Key('song-play-note'));
      expect(tester.widget<FilledButton>(noteButton).onPressed, isNull);
      await tester.tap(find.byKey(const Key('song-toggle')));
      expect(toggles, 1);
      expect(notes, 0);
      await _pumpCard(tester, running: true, onPlayNote: () => notes++);
      await tester.tap(noteButton);
      expect(notes, 1);
      expect(find.byTooltip('Pause song'), findsOneWidget);
    },
  );

  testWidgets('song choice and restart call supplied host handlers', (
    tester,
  ) async {
    var chooses = 0;
    var restarts = 0;
    await _pumpCard(
      tester,
      onChooseSong: () => chooses++,
      onReset: () => restarts++,
    );
    await tester.tap(find.byKey(const Key('song-chooser')));
    expect(chooses, 1);
    expect(find.text('Choose a song'), findsNothing);
    await tester.tap(find.byKey(const Key('song-restart')));
    expect(restarts, 1);
  });

  testWidgets('standalone song picker retains access to all catalog songs', (
    tester,
  ) async {
    SongDefinition? chosen;
    await _pumpCard(tester, onSongChanged: (song) => chosen = song);
    await tester.tap(find.byKey(const Key('song-chooser')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a song'), findsOneWidget);
    await tester.tap(find.text('Another melody'));
    await tester.pumpAndSettle();
    expect(chosen, same(_secondSong));
  });

  testWidgets('count-in and successful timing have accessible feedback', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final game = SongGame(_firstSong);
    await _pumpCard(tester, running: true, game: game);
    expect(find.bySemanticsLabel('Count-in 4'), findsOneWidget);
    expect(find.text('Listen to the count-in'), findsOneWidget);
    game.hit(const Duration(seconds: 3));
    await _pumpCard(
      tester,
      running: true,
      game: game,
      position: const Duration(seconds: 3),
    );
    expect(find.text('Perfect timing!'), findsOneWidget);
    expect(find.bySemanticsLabel('Score 100'), findsOneWidget);
    expect(find.bySemanticsLabel('Combo 1x'), findsOneWidget);
    expect(find.bySemanticsLabel('Notes hit 1/2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'completion retains the result and offers replay within the same bounds',
    (tester) async {
      final game = SongGame(_firstSong)
        ..hit(const Duration(seconds: 3))
        ..update(_firstSong.duration);
      await _pumpCard(
        tester,
        height: 350,
        scale: 2,
        game: game,
        position: _firstSong.duration,
      );
      expect(find.text('You made music!'), findsOneWidget);
      expect(find.text('Best combo 1x'), findsOneWidget);
      expect(find.byTooltip('Play again'), findsOneWidget);
      expect(find.text('50% hit'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('song-play-note')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('song stage distinguishes holding target from leaving it', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      running: true,
      position: const Duration(seconds: 4),
      targetIsLive: true,
      inTarget: true,
    );
    expect(find.text('In target - hold here'), findsOneWidget);
    await _pumpCard(
      tester,
      running: true,
      position: const Duration(seconds: 4),
      targetIsLive: true,
    );
    expect(find.text('Hold in target to hit notes'), findsOneWidget);
  });

  testWidgets('loading can be canceled and paused progress offers resume', (
    tester,
  ) async {
    var cancellations = 0;
    var choices = 0;
    await _pumpCard(
      tester,
      starting: true,
      onToggle: () => cancellations++,
      onChooseSong: () => choices++,
    );
    expect(find.byTooltip('Cancel start'), findsOneWidget);
    expect(find.text('Getting your song ready...'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('song-chooser')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('song-toggle')));
    expect(cancellations, 1);
    expect(choices, 0);
    await _pumpCard(tester, position: const Duration(seconds: 2));
    expect(find.byTooltip('Resume song'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  double scale = 1,
  double height = 420,
  bool running = false,
  bool starting = false,
  SongGame? game,
  Duration position = Duration.zero,
  VoidCallback? onPlayNote,
  VoidCallback? onToggle,
  VoidCallback? onReset,
  VoidCallback? onChooseSong,
  ValueChanged<SongDefinition>? onSongChanged,
  Widget? targetIndicator,
  bool inTarget = false,
  bool targetIsLive = false,
}) => tester.pumpWidget(
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
          height: height,
          child: SongPlayCard(
            songs: const [_firstSong, _secondSong],
            song: _firstSong,
            game: game ?? SongGame(_firstSong),
            position: position,
            running: running,
            starting: starting,
            onPlayNote: onPlayNote ?? () {},
            onSongChanged: onSongChanged ?? (_) {},
            onToggle: onToggle ?? () {},
            onReset: onReset ?? () {},
            onChooseSong: onChooseSong,
            targetIndicator: targetIndicator,
            inTarget: inTarget,
            targetIsLive: targetIsLive,
          ),
        ),
      ),
    ),
  ),
);
