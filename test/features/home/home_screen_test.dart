import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/app.dart';
import 'package:rehab_rhapsody/features/audio/demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/audio/song_audio_player.dart';
import 'package:rehab_rhapsody/features/baton/baton_transport.dart';
import 'package:rehab_rhapsody/features/demo/demo_controller.dart';
import 'package:rehab_rhapsody/features/home/home_controller.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';
import 'package:rehab_rhapsody/features/home/home_panels.dart';
import 'package:rehab_rhapsody/features/songs/song_catalog.dart';
import 'package:rehab_rhapsody/features/songs/song_session.dart';
import 'package:rehab_rhapsody/theme/app_theme.dart';

import '../../support/load_test_fonts.dart';

const _phones = [
  (size: Size(320, 568), top: 20.0, bottom: 0.0),
  (size: Size(375, 667), top: 20.0, bottom: 0.0),
  (size: Size(393, 852), top: 59.0, bottom: 34.0),
  (size: Size(430, 932), top: 59.0, bottom: 34.0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  for (final phone in _phones) {
    for (final scale in [1.0, 2.0]) {
      final device =
          '${phone.size.width.toInt()}x${phone.size.height.toInt()} at ${scale}x';
      testWidgets('all four play modes fit without scrolling on $device', (
        tester,
      ) async {
        configurePhone(
          tester,
          size: phone.size,
          top: phone.top,
          bottom: phone.bottom,
          textScale: scale,
        );
        final h = _Harness();
        await _pumpApp(tester, h);
        for (final mode in PlayMode.values) {
          h.home.selectMode(mode);
          await tester.pumpAndSettle();
          expect(find.text('Rehab Rhapsody'), findsOneWidget);
          _expectFixedScreen(tester, phone, reason: '$device / ${mode.label}');
          expect(find.byTooltip('Settings').hitTestable(), findsOneWidget);
          expect(
            find.byTooltip('Baton settings').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Choose play mode').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Adjust target').hitTestable(),
            findsOneWidget,
          );
          if (mode == PlayMode.song) {
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
            expect(
              find.byKey(const Key('song-play-note')).hitTestable(),
              findsOneWidget,
            );
          } else {
            expect(
              find.byKey(const Key('practice-toggle')).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('practice-reset')).hitTestable(),
              findsOneWidget,
            );
            for (final midi in demoMidiNotes) {
              expect(
                find.byKey(ValueKey('practice-note-$midi')).hitTestable(),
                findsOneWidget,
              );
            }
          }
        }
        await _disposeApp(tester, h);
      });

      testWidgets('every settings page fits without scrolling on $device', (
        tester,
      ) async {
        configurePhone(
          tester,
          size: phone.size,
          top: phone.top,
          bottom: phone.bottom,
          textScale: scale,
        );
        final h = _Harness();
        for (final panel in HomePanel.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: HomePanelScreen(
                key: ValueKey(panel),
                home: h.home,
                demo: h.demo,
                initialPanel: panel,
                samples: const [0.2, 0.5, 0.65, 0.7],
                motionIsLive: false,
                targetLow: 0.6,
                targetHigh: 0.7,
              ),
            ),
          );
          await tester.pumpAndSettle();
          _expectFixedScreen(tester, phone, reason: '$device / ${panel.title}');
          expect(
            find.byTooltip('Close settings').hitTestable(),
            findsOneWidget,
          );
          if (panel != HomePanel.settings) {
            expect(
              find.byTooltip('Back to settings').hitTestable(),
              findsOneWidget,
            );
          }
          if (panel == HomePanel.help) {
            for (var page = 1; page < 5; page++) {
              await tester.tap(find.text('Next'));
              await tester.pumpAndSettle();
              _expectFixedScreen(
                tester,
                phone,
                reason: '$device / help page ${page + 1}',
              );
            }
            expect(find.text('Done').hitTestable(), findsOneWidget);
          }
        }
        await _disposeApp(tester, h);
      });
    }
  }

  testWidgets(
    'mode chooser returns to the player and settings changes update real state',
    (tester) async {
      configurePhone(tester);
      final h = _Harness();
      await _pumpApp(tester, h);
      await tester.tap(find.bySemanticsLabel('Choose play mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rhythm'));
      await tester.pumpAndSettle();
      expect(h.home.mode, PlayMode.rhythm);
      expect(find.byType(HomePanelScreen), findsNothing);
      expect(
        find.byKey(const Key('practice-note-60')).hitTestable(),
        findsOneWidget,
      );

      await _openSetting(tester, 'Instrument');
      await tester.tap(find.text('Flute'));
      await tester.pumpAndSettle();
      expect(h.home.instrument, Instrument.flute);
      expect(find.byType(HomePanelScreen), findsOneWidget);
      await _closeSettings(tester);

      await _openSetting(tester, 'Volume');
      final originalVolume = h.home.volume;
      await tester.drag(find.byType(Slider), const Offset(70, 0));
      await tester.pump();
      expect(h.home.volume, greaterThan(originalVolume));
      expect(find.text('${h.home.volume.round()}%'), findsOneWidget);
      await _closeSettings(tester);

      await _openSetting(tester, 'Tempo');
      final originalTempo = h.home.tempo;
      await tester.drag(find.byType(Slider), const Offset(70, 0));
      await tester.pump();
      expect(h.home.tempo, greaterThan(originalTempo));
      expect(find.text('${h.home.tempo.round()} BPM'), findsOneWidget);
      await _closeSettings(tester);
      await _disposeApp(tester, h);
    },
  );

  testWidgets(
    'Songs keeps its track tempo and its chooser changes the real song',
    (tester) async {
      configurePhone(tester);
      final h = _Harness();
      await _pumpApp(tester, h);
      await _openSetting(tester, 'Tempo');
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(
        find.text('Song tempo follows its backing track.'),
        findsOneWidget,
      );
      await _closeSettings(tester);
      await tester.tap(find.byKey(const Key('song-chooser')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a song'), findsOneWidget);
      await tester.tap(find.text(demoSongs[1].title));
      await tester.pumpAndSettle();
      expect(h.demo.songSession!.song.id, demoSongs[1].id);
      expect(find.byType(HomePanelScreen), findsNothing);
      expect(find.text(demoSongs[1].title), findsOneWidget);
      await _disposeApp(tester, h);
    },
  );

  testWidgets(
    'target page captures live position and follows controller updates',
    (tester) async {
      configurePhone(tester);
      final h = _Harness();
      await _pumpApp(tester, h);
      await h.demo.connect();
      h.baton.send(_packet());
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Adjust target'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Use current position');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pump();
      expect(h.demo.targetCenter, closeTo(0.5, 1e-5));
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('In target'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('target-height-slider')),
        const Offset(70, 0),
      );
      await tester.pump();
      expect(h.demo.targetCenter, greaterThan(0.5));
      expect(h.demo.targetHigh - h.demo.targetLow, closeTo(0.1, 1e-9));
      await _closeSettings(tester);
      expect(
        find.text('Target ${(h.demo.targetCenter * 100).round()}%'),
        findsOneWidget,
      );
      await _disposeApp(tester, h);
    },
  );

  testWidgets('opening settings pauses audio and closing does not resume it', (
    tester,
  ) async {
    configurePhone(tester);
    final h = _Harness(mode: PlayMode.free);
    await _pumpApp(tester, h);
    await h.demo.playPad(60);
    await tester.pump();
    expect(h.home.isRunning, isTrue);
    expect(h.home.currentNote?.midiNote, 60);
    final stops = h.audio.stops;
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(h.home.isRunning, isFalse);
    expect(h.home.currentNote, isNull);
    expect(h.audio.stops, greaterThan(stops));
    await _closeSettings(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(h.home.isRunning, isFalse);
    expect(h.home.currentNote, isNull);
    expect(
      find.bySemanticsLabel('Start session').hitTestable(),
      findsOneWidget,
    );
    await _disposeApp(tester, h);
  });

  testWidgets('target capture disables when live baton readings disappear', (
    tester,
  ) async {
    configurePhone(tester);
    final h = _Harness();
    await _pumpApp(tester, h);
    await tester.tap(find.bySemanticsLabel('Adjust target'));
    await tester.pumpAndSettle();
    final capture = find.widgetWithText(FilledButton, 'Use current position');
    expect(tester.widget<FilledButton>(capture).onPressed, isNull);
    expect(find.text('Waiting for baton'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, DemoController.minimumTargetCenter);
    expect(slider.max, DemoController.maximumTargetCenter);
    expect(slider.semanticFormatterCallback!(0.65), '65 percent');

    await h.demo.connect();
    h.baton.send(_packet());
    await tester.pump();
    expect(tester.widget<FilledButton>(capture).onPressed, isNotNull);
    await h.demo.disconnect();
    await tester.pump();
    expect(tester.widget<FilledButton>(capture).onPressed, isNull);
    expect(find.text('Waiting for baton'), findsOneWidget);
    await _disposeApp(tester, h);
  });

  testWidgets(
    'replacing an injected demo pauses the old one and uses the new one',
    (tester) async {
      configurePhone(tester);
      final first = _Harness(mode: PlayMode.free);
      final second = _Harness(mode: PlayMode.guided);
      await _pumpApp(tester, first);
      await first.demo.playPad(64);
      await tester.pump();
      expect(first.home.isRunning, isTrue);

      await _pumpApp(tester, second);
      expect(first.home.isRunning, isFalse);
      expect(first.home.currentNote, isNull);
      expect(find.text('Guided'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('practice-note-60')));
      await tester.pump();
      expect(second.home.currentNote?.midiNote, 60);
      expect(_noteLabel(tester), 'Current note C, octave 4');

      // An injected controller remains owned by its caller after replacement.
      first.demo.setTargetCenter(0.4);
      expect(first.demo.targetCenter, 0.4);
      first.demo.dispose();
      first.home.dispose();
      await _disposeApp(tester, second);
    },
  );

  testWidgets('baton panel connects and updates independently while open', (
    tester,
  ) async {
    configurePhone(tester);
    final h = _Harness();
    await _pumpApp(tester, h);
    await tester.tap(find.byTooltip('Baton settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect baton'));
    await tester.pumpAndSettle();
    expect(h.baton.connects, 1);
    expect(find.text('Disconnect baton'), findsOneWidget);
    expect(find.text('Baton linked'), findsOneWidget);
    h.baton.send(_packet());
    await tester.pumpAndSettle();
    expect(find.textContaining('readings/s'), findsOneWidget);
    await tester.tap(find.text('Disconnect baton'));
    await tester.pumpAndSettle();
    expect(find.text('Connect baton'), findsOneWidget);
    expect(h.home.isRunning, isFalse);
    await _closeSettings(tester);
    await _disposeApp(tester, h);
  });

  testWidgets(
    'session time pauses resumes and resets without moving controls',
    (tester) async {
      configurePhone(
        tester,
        size: const Size(320, 568),
        top: 20,
        bottom: 0,
        textScale: 2,
      );
      final h = _Harness(mode: PlayMode.free);
      await _pumpApp(tester, h);
      final initialPlayRect = tester.getRect(
        find.byKey(const Key('practice-toggle')),
      );
      await tester.tap(find.bySemanticsLabel('Start session'));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.bySemanticsLabel('Pause session'));
      await tester.pump();
      expect(h.home.elapsed, const Duration(seconds: 3));
      expect(find.text('00:00:03'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('practice-toggle'))),
        initialPlayRect,
      );
      await tester.tap(find.bySemanticsLabel('Start session'));
      await tester.pump(const Duration(seconds: 1));
      expect(h.home.elapsed, const Duration(seconds: 4));
      await tester.tap(find.byKey(const Key('practice-reset')));
      await tester.pumpAndSettle();
      expect(h.home.isRunning, isFalse);
      expect(h.home.elapsed, Duration.zero);
      expect(find.text('00:00:00'), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      await _disposeApp(tester, h);
    },
  );

  testWidgets(
    'confirmed audio updates accessible current note and pause clears it',
    (tester) async {
      configurePhone(tester);
      final h = _Harness(mode: PlayMode.free);
      await _pumpApp(tester, h);
      expect(_noteLabel(tester), 'Current note, no note playing');
      await h.demo.playPad(60);
      await tester.pump();
      expect(_noteLabel(tester), 'Current note C, octave 4');
      h.demo.pause();
      await tester.pump();
      expect(_noteLabel(tester), 'Current note, no note playing');
      await _disposeApp(tester, h);
    },
  );

  testWidgets(
    'backgrounding pauses and returning never automatically resumes',
    (tester) async {
      configurePhone(tester);
      final h = _Harness(mode: PlayMode.free);
      await _pumpApp(tester, h);
      await h.demo.toggleSession();
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(h.home.isRunning, isFalse);
      expect(h.home.elapsed, const Duration(seconds: 2));
      expect(h.baton.disconnects, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(h.home.isRunning, isFalse);
      expect(h.home.elapsed, const Duration(seconds: 2));
      await _disposeApp(tester, h);
    },
  );
}

String? _noteLabel(WidgetTester tester) => tester
    .widget<Semantics>(find.byKey(const Key('practice-current-note')))
    .properties
    .label;

Future<void> _pumpApp(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(RehabRhapsodyApp(demoController: h.demo));
  await tester.pumpAndSettle();
}

Future<void> _disposeApp(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  h.demo.dispose();
  h.home.dispose();
  await tester.pump();
}

Future<void> _openSetting(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _closeSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Close settings'));
  await tester.pumpAndSettle();
}

void _expectFixedScreen(
  WidgetTester tester,
  ({Size size, double top, double bottom}) phone, {
  required String reason,
}) {
  expect(tester.takeException(), isNull, reason: reason);
  expect(find.byType(Scrollable), findsNothing, reason: reason);
  final controls = find.byWidgetPredicate(
    (widget) =>
        widget is ButtonStyleButton || widget is IconButton || widget is Slider,
  );
  for (final element in controls.evaluate()) {
    final finder = find.byElementPredicate(
      (candidate) => identical(candidate, element),
    );
    final rect = tester.getRect(finder);
    expect(
      rect.width,
      greaterThanOrEqualTo(44),
      reason: '$reason / ${element.widget.runtimeType} width',
    );
    expect(
      rect.height,
      greaterThanOrEqualTo(44),
      reason: '$reason / ${element.widget.runtimeType} height',
    );
    expect(rect.left, greaterThanOrEqualTo(-0.5), reason: reason);
    expect(
      rect.right,
      lessThanOrEqualTo(phone.size.width + 0.5),
      reason: reason,
    );
    expect(rect.top, greaterThanOrEqualTo(phone.top - 0.5), reason: reason);
    expect(
      rect.bottom,
      lessThanOrEqualTo(phone.size.height - phone.bottom + 0.5),
      reason: reason,
    );
    expect(
      finder.hitTestable(),
      findsOneWidget,
      reason: '$reason / ${element.widget.runtimeType} is reachable',
    );
  }
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

class _Harness {
  _Harness({PlayMode mode = PlayMode.song}) {
    home.selectMode(mode);
    demo = DemoController(
      home: home,
      transport: baton,
      audio: audio,
      songSession: SongSession(
        audio: _FakeSongAudio(),
        now: () => Duration.zero,
      ),
      now: () => Duration.zero,
    );
  }
  final home = HomeController();
  final baton = _FakeBaton();
  final audio = _FakeAudio();
  late final DemoController demo;
}

class _FakeAudio extends DemoAudioEngine {
  int stops = 0;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> play({
    required int midiNote,
    required Instrument instrument,
    required double volume,
  }) async {}
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeSongAudio implements SongAudioPlayer {
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<void> get completions => const Stream.empty();
  @override
  Future<void> load(String assetPath) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
}

class _FakeBaton implements BatonTransport {
  final _connections = StreamController<BatonConnection>.broadcast(sync: true);
  final _packets = StreamController<List<int>>.broadcast(sync: true);
  BatonConnection _connection = const BatonConnection(
    status: BatonConnectionStatus.idle,
  );
  int connects = 0;
  int disconnects = 0;
  @override
  BatonConnection get connection => _connection;
  @override
  Stream<BatonConnection> get connections => _connections.stream;
  @override
  Stream<List<int>> get packets => _packets.stream;
  void send(List<int> bytes) => _packets.add(bytes);
  void _emit(BatonConnectionStatus status) {
    _connection = BatonConnection(status: status, deviceName: 'Test baton');
    _connections.add(_connection);
  }

  @override
  Future<void> connect() async {
    connects++;
    _emit(BatonConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    _emit(BatonConnectionStatus.disconnected);
  }

  @override
  Future<void> dispose() async {
    await _connections.close();
    await _packets.close();
  }
}

List<int> _packet() {
  final data = ByteData(20);
  data.setUint8(0, 1);
  data.setUint16(2, 1, Endian.little);
  data.setUint32(4, 100000, Endian.little);
  data.setInt16(12, 8197, Endian.little);
  return data.buffer.asUint8List();
}
