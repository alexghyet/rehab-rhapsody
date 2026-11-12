import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/audio/song_audio_player.dart';
import 'package:rehab_rhapsody/features/baton/baton_transport.dart';
import 'package:rehab_rhapsody/features/demo/demo_controller.dart';
import 'package:rehab_rhapsody/features/home/home_controller.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';
import 'package:rehab_rhapsody/features/songs/song_session.dart';

void main() {
  testWidgets(
    'capturing either end of the movement range keeps it inside the thin target',
    (tester) async {
      final demo = _DemoHarness();
      await demo.controller.connect();
      demo.baton.send(_packet(1, 100000, tiltDegrees: -80));
      demo.controller.useCurrentPositionAsTarget();
      expect(demo.controller.targetCenter, 0.05);
      expect(demo.controller.inTarget, isTrue);
      demo.baton.send(_packet(2, 1100000, tiltDegrees: 80));
      demo.controller.useCurrentPositionAsTarget();
      expect(demo.controller.targetCenter, 0.95);
      expect(demo.controller.inTarget, isTrue);
      demo.controller.reset();
      expect(demo.controller.targetCenter, 0.95);
      expect(
        demo.controller.targetHigh - demo.controller.targetLow,
        closeTo(0.10, 1e-9),
      );
      await demo.dispose(tester);
    },
  );

  testWidgets(
    'rest does not truncate a gesture note but pause still stops it',
    (tester) async {
      final demo = _DemoHarness();
      await demo.controller.connect();
      await demo.controller.toggleSession();
      demo.baton.send(_packet(1, 100000, moving: true));
      await tester.pump();
      final stops = demo.audio.stopCount;
      await demo.pump(tester, const Duration(milliseconds: 60));
      demo.baton.send(_packet(2, 160000));
      expect(demo.audio.stopCount, stops);
      expect(demo.home.currentNote, isNotNull);
      await demo.pump(tester, const Duration(milliseconds: 400));
      expect(demo.home.currentNote, isNotNull);
      demo.controller.pause();
      expect(demo.audio.stopCount, greaterThan(stops));
      expect(demo.home.currentNote, isNull);
      await demo.dispose(tester);
    },
  );

  testWidgets(
    'a stationary in-zone hold hits successive target pitches once on time',
    (tester) async {
      final demo = _DemoHarness(songs: true);
      demo.home.selectMode(PlayMode.song);
      await demo.controller.connect();
      await demo.controller.toggleSession();
      final song = demo.controller.songSession!;
      demo.baton.send(_packet(1, 100000, tiltDegrees: 18));
      demo.songAudio.positionEvents.add(
        song.song.notes[0].at - const Duration(milliseconds: 200),
      );
      expect(song.game.hits, 0);
      demo.songAudio.positionEvents.add(song.song.notes[0].at);
      await tester.pump();
      expect(song.game.hits, 1);
      expect(demo.controller.inTarget, isTrue);
      expect(demo.controller.mapping!.isMoving, isFalse);
      expect(demo.audio.plays.single.midiNote, song.song.notes[0].midiNote);
      // The held angle chooses a different pitch in Free play. Songs always
      // plays the chart's pitch without needing another gesture.
      expect(
        demo.controller.mapping!.midiNote,
        isNot(song.song.notes[0].midiNote),
      );
      demo.songAudio.positionEvents.add(song.song.notes[1].at);
      await tester.pump();
      expect(song.game.hits, 2);
      demo.baton.send(_packet(2, 160000, tiltDegrees: 18));
      demo.songAudio.positionEvents.add(song.song.notes[1].at);
      await tester.pump();
      expect(song.game.hits, 2);
      expect(demo.audio.plays, hasLength(2));
      demo.baton.emit(BatonConnectionStatus.disconnected);
      expect(song.running, isFalse);
      expect(demo.home.isRunning, isFalse);
      final hits = song.game.hits;
      await demo.controller.playSongNote();
      expect(song.game.hits, hits);
      await demo.dispose(tester);
    },
  );

  testWidgets(
    'held position hits on interpolated audio ticks without another gesture',
    (tester) async {
      final demo = _DemoHarness(songs: true);
      demo.home.selectMode(PlayMode.song);
      await demo.controller.connect();
      await demo.controller.toggleSession();
      final song = demo.controller.songSession!;
      demo.baton.send(_packet(1, 100000, tiltDegrees: 18));
      demo.songAudio.positionEvents.add(
        song.song.notes[0].at - const Duration(milliseconds: 10),
      );
      expect(song.game.hits, 0);
      await demo.pump(tester, const Duration(milliseconds: 33));
      expect(song.game.hits, 1);
      expect(demo.audio.plays.single.midiNote, song.song.notes[0].midiNote);
      await demo.pump(tester, const Duration(milliseconds: 33));
      expect(song.game.hits, 1);
      await demo.dispose(tester);
    },
  );

  testWidgets('fast motion outside the target cannot score; late entry can', (
    tester,
  ) async {
    final demo = _DemoHarness(songs: true);
    demo.home.selectMode(PlayMode.song);
    await demo.controller.connect();
    await demo.controller.toggleSession();
    final song = demo.controller.songSession!;
    final firstAt = song.song.notes.first.at;
    demo.baton.send(_packet(1, 100000, moving: true));
    demo.songAudio.positionEvents.add(firstAt);
    expect(demo.controller.inTarget, isFalse);
    expect(song.game.hits, 0);
    expect(demo.audio.plays, isEmpty);
    // Adjusting the target to the patient's comfortable held position does
    // not reset music/results. The next clock tick can accept the due note.
    demo.controller.useCurrentPositionAsTarget();
    expect(demo.controller.targetCenter, closeTo(0.5, 1e-6));
    demo.songAudio.positionEvents.add(
      firstAt + const Duration(milliseconds: 100),
    );
    await tester.pump();
    expect(song.game.hits, 1);
    expect(song.position, firstAt + const Duration(milliseconds: 100));
    expect(demo.home.isRunning, isTrue);
    final width = demo.controller.targetHigh - demo.controller.targetLow;
    demo.controller.setTargetCenter(0.8);
    expect(demo.controller.inTarget, isFalse);
    expect(
      demo.controller.targetHigh - demo.controller.targetLow,
      closeTo(width, 1e-9),
    );
    expect(song.game.hits, 1);
    demo.controller.setTargetCenter(double.nan);
    expect(demo.controller.targetCenter, 0.8);
    demo.controller.setTargetCenter(10);
    expect(demo.controller.targetCenter, 0.95);
    demo.controller.setTargetCenter(-10);
    expect(demo.controller.targetCenter, 0.05);
    await demo.dispose(tester);
  });

  testWidgets(
    'stale or invalid gravity cannot keep earning held-target notes',
    (tester) async {
      final demo = _DemoHarness(songs: true);
      demo.home.selectMode(PlayMode.song);
      await demo.controller.connect();
      await demo.controller.toggleSession();
      final song = demo.controller.songSession!;
      demo.baton.send(_packet(1, 100000, tiltDegrees: 18));
      expect(demo.controller.inTarget, isTrue);
      await demo.pump(tester, const Duration(milliseconds: 251));
      demo.songAudio.positionEvents.add(song.song.notes[0].at);
      expect(demo.controller.connection.isConnected, isTrue);
      expect(demo.controller.inTarget, isFalse);
      expect(song.game.hits, 0);
      demo.baton.send(_packet(2, 351000, tiltDegrees: 18, gravityG: 2));
      expect(demo.controller.hasFreshTargetReading, isFalse);
      expect(song.game.hits, 0);
      demo.baton.send(_packet(3, 411000, tiltDegrees: 18));
      await tester.pump();
      expect(song.game.hits, 1);
      demo.baton.send(_packet(4, 471000, gravityG: 0));
      demo.songAudio.positionEvents.add(song.song.notes[1].at);
      expect(song.game.hits, 1);
      await demo.dispose(tester);
    },
  );

  testWidgets(
    'leaving target misses a note; returning hits only the current due note',
    (tester) async {
      final demo = _DemoHarness(songs: true);
      demo.home.selectMode(PlayMode.song);
      await demo.controller.connect();
      await demo.controller.toggleSession();
      final song = demo.controller.songSession!;
      demo.baton.send(_packet(1, 100000, tiltDegrees: 18));
      demo.songAudio.positionEvents.add(song.song.notes[0].at);
      await tester.pump();
      demo.baton.send(_packet(2, 1100000, tiltDegrees: -18));
      expect(demo.controller.inTarget, isFalse);
      demo.songAudio.positionEvents.add(
        song.song.notes[1].at + const Duration(milliseconds: 281),
      );
      expect(song.game.hits, 1);
      expect(song.game.misses, 1);
      expect(demo.home.isRunning, isTrue);
      demo.baton.send(_packet(3, 2100000, tiltDegrees: 18));
      demo.songAudio.positionEvents.add(song.song.notes[3].at);
      await tester.pump();
      expect(song.game.hits, 2);
      expect(song.game.misses, 2);
      expect(demo.audio.plays, hasLength(2));
      expect(demo.audio.plays.last.midiNote, song.song.notes[3].midiNote);
      await demo.dispose(tester);
    },
  );

  testWidgets(
    'pause resume reset and reconnect require a fresh target reading',
    (tester) async {
      final demo = _DemoHarness(songs: true);
      demo.home.selectMode(PlayMode.song);
      await demo.controller.connect();
      await demo.controller.toggleSession();
      final song = demo.controller.songSession!;
      demo.baton.send(_packet(1, 100000, tiltDegrees: 18));
      demo.controller.pause();
      await demo.controller.toggleSession();
      demo.songAudio.positionEvents.add(song.song.notes[0].at);
      expect(demo.controller.inTarget, isFalse);
      expect(song.game.hits, 0);
      demo.baton.send(_packet(2, 160000, tiltDegrees: 18));
      await tester.pump();
      expect(song.game.hits, 1);
      demo.controller.reset();
      await demo.controller.toggleSession();
      demo.songAudio.positionEvents.add(song.song.notes[0].at);
      expect(song.game.hits, 0);
      demo.baton.emit(BatonConnectionStatus.disconnected);
      await demo.controller.connect();
      await demo.controller.toggleSession();
      expect(song.game.hits, 0);
      expect(demo.controller.inTarget, isFalse);
      demo.baton.send(_packet(1, 100000, tiltDegrees: 18));
      await tester.pump();
      expect(song.game.hits, 1);
      await demo.dispose(tester);
    },
  );

  testWidgets(
    'song completion pauses home and mode changes cancel pending backing load',
    (tester) async {
      final demo = _DemoHarness(songs: true);
      demo.home.selectMode(PlayMode.song);
      await demo.controller.toggleSession();
      demo.songAudio.completionEvents.add(null);
      expect(demo.home.isRunning, isFalse);
      expect(demo.controller.songSession!.game.isComplete, isTrue);
      demo.controller.selectSong(demo.controller.songSession!.song);
      final gate = demo.songAudio.seekGate = Completer<void>();
      final starting = demo.controller.toggleSession();
      await tester.pump();
      demo.home.selectMode(PlayMode.free);
      gate.complete();
      await starting;
      expect(demo.home.isRunning, isFalse);
      expect(demo.controller.songSession!.running, isFalse);
      await demo.dispose(tester);
    },
  );
  testWidgets(
    'first-session rapid pads share initialization and latest pad wins',
    (tester) async {
      final demo = _DemoHarness();
      final initialize = Completer<void>();
      demo.audio.initializeGate = initialize;

      final older = demo.controller.playPad(60);
      final newer = demo.controller.playPad(64);
      expect(demo.controller.starting, isTrue);
      expect(demo.audio.plays, isEmpty);
      initialize.complete();
      await Future.wait([older, newer]);

      expect(demo.home.isRunning, isTrue);
      expect(demo.audio.plays.map((play) => play.midiNote), [64]);
      expect(demo.home.currentNote?.midiNote, 64);
      await demo.dispose(tester);
    },
  );

  testWidgets('a second Start tap still cancels pending initialization', (
    tester,
  ) async {
    final demo = _DemoHarness();
    final initialize = Completer<void>();
    demo.audio.initializeGate = initialize;
    final starting = demo.controller.toggleSession();
    expect(demo.controller.starting, isTrue);

    await demo.controller.toggleSession();
    initialize.complete();
    await starting;
    expect(demo.controller.starting, isFalse);
    expect(demo.home.isRunning, isFalse);
    expect(demo.audio.plays, isEmpty);
    await demo.dispose(tester);
  });

  testWidgets(
    'a late audio start after pause never revives the displayed note',
    (tester) async {
      final demo = _DemoHarness();
      await demo.controller.toggleSession();
      final gate = Completer<void>();
      demo.audio.playGates[0] = gate;
      final playing = demo.controller.playPad(60);
      await tester.pump();
      expect(demo.audio.plays.single.midiNote, 60);
      final stopsBeforePause = demo.audio.stopCount;

      demo.controller.pause();
      gate.complete();
      await playing;
      await demo.pump(tester, const Duration(seconds: 1));

      expect(demo.home.isRunning, isFalse);
      expect(demo.home.currentNote, isNull);
      expect(demo.audio.stopCount, greaterThan(stopsBeforePause));
      await demo.dispose(tester);
    },
  );

  testWidgets('rapid pad requests display only the latest accepted voice', (
    tester,
  ) async {
    final demo = _DemoHarness();
    await demo.controller.toggleSession();
    final olderGate = Completer<void>();
    final newerGate = Completer<void>();
    demo.audio.playGates.addAll({0: olderGate, 1: newerGate});
    final older = demo.controller.playPad(60);
    final newer = demo.controller.playPad(64);
    expect(demo.audio.plays.map((play) => play.midiNote), [60, 64]);

    newerGate.complete();
    await newer;
    expect(demo.home.currentNote?.midiNote, 64);
    olderGate.complete();
    await older;
    expect(demo.home.currentNote?.midiNote, 64);
    await demo.pump(tester, const Duration(milliseconds: 601));
    expect(demo.home.currentNote, isNull);
    await demo.dispose(tester);
  });

  testWidgets('only valid forward motion updates the live chart and counters', (
    tester,
  ) async {
    final demo = _DemoHarness();
    await demo.controller.connect();
    final first = _packet(1, 100000);
    demo.baton.send(first);
    expect(demo.controller.isLive, isTrue);
    expect(demo.controller.acceptedPackets, 1);
    expect(demo.controller.latestFrame?.sequence, 1);
    expect(demo.controller.samples, hasLength(1));
    // Sensor updates alone do not start an app session or play audio.
    expect(demo.home.isRunning, isFalse);
    expect(demo.audio.plays, isEmpty);

    demo.baton.send(first);
    demo.baton.send(first.sublist(1));
    demo.baton.send([...first]..[0] = 2);
    expect(demo.controller.rejectedPackets, 3);
    expect(demo.controller.samples, hasLength(1));

    await demo.pump(tester, const Duration(milliseconds: 20));
    demo.baton.send(_packet(3, 120000));
    demo.baton.send(_packet(2, 110000));
    expect(demo.controller.acceptedPackets, 2);
    expect(demo.controller.rejectedPackets, 4);
    expect(demo.controller.latestFrame?.sequence, 3);
    expect(demo.controller.sampleRate, closeTo(50, 1e-8));
    expect(demo.controller.samples, hasLength(2));
    await demo.dispose(tester);
  });

  testWidgets('disconnect pauses the session, clears motion and stops audio', (
    tester,
  ) async {
    final demo = _DemoHarness();
    await demo.controller.connect();
    await demo.controller.playPad(67);
    expect(demo.home.currentNote?.midiNote, 67);
    demo.baton.send(_packet(1, 100000));
    final stops = demo.audio.stopCount;

    demo.baton.emit(BatonConnectionStatus.disconnected);
    expect(demo.home.isRunning, isFalse);
    expect(demo.home.currentNote, isNull);
    expect(demo.controller.isLive, isFalse);
    expect(demo.controller.latestFrame, isNull);
    expect(demo.audio.stopCount, greaterThan(stops));
    demo.baton.send(_packet(2, 120000, moving: true));
    expect(demo.controller.acceptedPackets, 0);
    await demo.pump(tester, const Duration(seconds: 1));
    expect(demo.home.isRunning, isFalse);
    expect(demo.audio.plays, hasLength(1));
    await demo.dispose(tester);
  });

  testWidgets('missing motion times out, stops playback and disconnects', (
    tester,
  ) async {
    final demo = _DemoHarness();
    await demo.controller.connect();
    await demo.controller.toggleSession();
    demo.baton.send(_packet(1, 100000, moving: true));
    await tester.pump();
    expect(demo.audio.plays, hasLength(1));
    final stops = demo.audio.stopCount;

    await demo.pump(tester, const Duration(milliseconds: 2201));
    expect(demo.baton.disconnectCount, 1);
    expect(demo.home.isRunning, isFalse);
    expect(demo.home.currentNote, isNull);
    expect(demo.controller.isLive, isFalse);
    expect(demo.controller.message, contains('fresh motion'));
    expect(demo.audio.stopCount, greaterThan(stops));
    await demo.dispose(tester);
  });

  testWidgets('Guided advances only after the requested note is accepted', (
    tester,
  ) async {
    final demo = _DemoHarness();
    demo.home.selectMode(PlayMode.guided);
    await demo.controller.playPad(62);
    expect(demo.audio.plays, isEmpty);
    expect(demo.controller.guidedStep, 0);
    expect(demo.controller.targetMidi, 60);

    await demo.controller.playPad(60);
    expect(demo.controller.guidedStep, 1);
    expect(demo.controller.targetMidi, 60);
    await demo.controller.playPad(60);
    expect(demo.controller.guidedStep, 2);
    expect(demo.controller.targetMidi, 67);
    await demo.controller.playPad(64);
    expect(demo.controller.guidedStep, 2);
    expect(demo.audio.plays, hasLength(2));
    await demo.controller.playPad(67);
    expect(demo.controller.guidedStep, 3);
    expect(demo.home.currentNote?.midiNote, 67);
    await demo.dispose(tester);
  });

  testWidgets('Rhythm plays moving samples on tempo beats and stops at rest', (
    tester,
  ) async {
    final demo = _DemoHarness();
    demo.home.selectMode(PlayMode.rhythm);
    demo.home.setTempo(120);
    await demo.controller.connect();
    await demo.controller.toggleSession();
    demo.baton.send(_packet(1, 100000, moving: true));
    await demo.pump(tester, const Duration(milliseconds: 499));
    expect(demo.audio.plays, isEmpty);
    expect(demo.controller.beat, 0);
    demo.baton.send(_packet(2, 599000, moving: true));
    await demo.pump(tester, const Duration(milliseconds: 1));
    expect(demo.audio.plays, hasLength(1));
    expect(demo.controller.beat, 1);

    demo.home.setTempo(60);
    await demo.pump(tester, const Duration(milliseconds: 999));
    expect(demo.audio.plays, hasLength(1));
    demo.baton.send(_packet(3, 1599000, moving: true));
    await demo.pump(tester, const Duration(milliseconds: 1));
    expect(demo.audio.plays, hasLength(2));

    await demo.pump(tester, const Duration(milliseconds: 20));
    demo.baton.send(_packet(4, 1620000));
    await demo.pump(tester, const Duration(seconds: 1));
    expect(demo.audio.plays, hasLength(2));
    expect(demo.home.currentNote, isNull);
    await demo.dispose(tester);
  });

  testWidgets('Rhythm resume requires fresh movement from the new session', (
    tester,
  ) async {
    final demo = _DemoHarness();
    demo.home.selectMode(PlayMode.rhythm);
    demo.home.setTempo(120);
    await demo.controller.connect();
    await demo.controller.toggleSession();
    demo.baton.send(_packet(1, 100000, moving: true));
    demo.controller.pause();
    await demo.controller.toggleSession();
    await demo.pump(tester, const Duration(milliseconds: 500));
    expect(demo.audio.plays, isEmpty);

    demo.baton.send(_packet(2, 600000, moving: true));
    await demo.pump(tester, const Duration(milliseconds: 499));
    demo.baton.send(_packet(3, 1099000, moving: true));
    await demo.pump(tester, const Duration(milliseconds: 1));
    expect(demo.audio.plays, hasLength(1));
    await demo.dispose(tester);
  });

  testWidgets(
    'Rhythm never repeats a stale moving sample while BLE stays linked',
    (tester) async {
      final demo = _DemoHarness();
      demo.home.selectMode(PlayMode.rhythm);
      demo.home.setTempo(120);
      await demo.controller.connect();
      await demo.controller.toggleSession();
      demo.baton.send(_packet(1, 100000, moving: true));

      await demo.pump(tester, const Duration(milliseconds: 500));
      expect(demo.controller.beat, 1);
      expect(demo.controller.connection.isConnected, isTrue);
      expect(demo.controller.isLive, isTrue);
      expect(demo.baton.disconnectCount, 0);
      expect(demo.audio.plays, isEmpty);

      // A fresh sample just before the next beat restores music without a
      // disconnect or session restart; stale state itself cannot trigger it.
      await demo.pump(tester, const Duration(milliseconds: 499));
      demo.baton.send(_packet(2, 1099000, moving: true));
      await demo.pump(tester, const Duration(milliseconds: 1));
      expect(demo.audio.plays, hasLength(1));
      expect(demo.home.isRunning, isTrue);
      await demo.dispose(tester);
    },
  );

  testWidgets('backgrounding invalidates pending audio initialization', (
    tester,
  ) async {
    final demo = _DemoHarness();
    final initialize = Completer<void>();
    demo.audio.initializeGate = initialize;
    final starting = demo.controller.toggleSession();
    expect(demo.controller.starting, isTrue);
    demo.controller.suspend();
    initialize.complete();
    await starting;
    expect(demo.controller.starting, isFalse);
    expect(demo.home.isRunning, isFalse);
    expect(demo.audio.plays, isEmpty);
    expect(demo.baton.disconnectCount, 1);
    demo.baton.emit(BatonConnectionStatus.connected);
    expect(demo.home.isRunning, isFalse);
    await demo.dispose(tester);
  });

  testWidgets('audio interruption pauses and never automatically resumes', (
    tester,
  ) async {
    final demo = _DemoHarness();
    await demo.controller.playPad(72);
    expect(demo.home.currentNote?.midiNote, 72);
    demo.audio.interruptionEvents.add(null);
    expect(demo.home.isRunning, isFalse);
    expect(demo.home.currentNote, isNull);
    expect(demo.controller.message, contains('interrupted'));
    await demo.pump(tester, const Duration(seconds: 1));
    expect(demo.home.isRunning, isFalse);
    expect(demo.audio.plays, hasLength(1));
    await demo.dispose(tester);
  });
}

class _DemoHarness {
  _DemoHarness({bool songs = false}) {
    controller = DemoController(
      home: home,
      transport: baton,
      audio: audio,
      songSession: songs
          ? SongSession(audio: songAudio, now: () => elapsed)
          : null,
      now: () => elapsed,
    );
  }

  final home = HomeController();
  final baton = _FakeBatonTransport();
  final audio = _FakeDemoAudioEngine();
  final songAudio = _FakeSongAudio();
  late final DemoController controller;
  Duration elapsed = Duration.zero;

  Future<void> pump(WidgetTester tester, Duration duration) async {
    elapsed += duration;
    await tester.pump(duration);
  }

  Future<void> dispose(WidgetTester tester) async {
    controller.dispose();
    home.dispose();
    await tester.pump();
  }
}

class _FakeSongAudio implements SongAudioPlayer {
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final completionEvents = StreamController<void>.broadcast(sync: true);
  Completer<void>? seekGate;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<void> get completions => completionEvents.stream;
  @override
  Future<void> load(String assetPath) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {
    await seekGate?.future;
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {
    await positionEvents.close();
    await completionEvents.close();
  }
}

class _FakeBatonTransport implements BatonTransport {
  final _connections = StreamController<BatonConnection>.broadcast(sync: true);
  final _packets = StreamController<List<int>>.broadcast(sync: true);
  BatonConnection _connection = const BatonConnection(
    status: BatonConnectionStatus.idle,
  );
  int disconnectCount = 0;

  @override
  BatonConnection get connection => _connection;
  @override
  Stream<BatonConnection> get connections => _connections.stream;
  @override
  Stream<List<int>> get packets => _packets.stream;

  void emit(BatonConnectionStatus status) {
    _connection = BatonConnection(status: status, deviceName: 'Test baton');
    _connections.add(_connection);
  }

  void send(List<int> packet) => _packets.add(packet);

  @override
  Future<void> connect() async => emit(BatonConnectionStatus.connected);
  @override
  Future<void> disconnect() async {
    ++disconnectCount;
    emit(BatonConnectionStatus.disconnected);
  }

  @override
  Future<void> dispose() async {
    await _connections.close();
    await _packets.close();
  }
}

class _FakeDemoAudioEngine extends DemoAudioEngine {
  final interruptionEvents = StreamController<void>.broadcast(sync: true);
  final plays = <({int midiNote, Instrument instrument, double volume})>[];
  final playGates = <int, Completer<void>>{};
  Completer<void>? initializeGate;
  int stopCount = 0;

  @override
  Stream<void> get interruptions => interruptionEvents.stream;
  @override
  Future<void> initialize() => initializeGate?.future ?? Future<void>.value();
  @override
  Future<void> play({
    required int midiNote,
    required Instrument instrument,
    required double volume,
  }) {
    final index = plays.length;
    plays.add((midiNote: midiNote, instrument: instrument, volume: volume));
    return playGates[index]?.future ?? Future<void>.value();
  }

  @override
  Future<void> stop() async => ++stopCount;
  @override
  Future<void> dispose() => interruptionEvents.close();
}

List<int> _packet(
  int sequence,
  int timestampUs, {
  bool moving = false,
  double tiltDegrees = 0,
  double gravityG = 1,
}) {
  final data = ByteData(20);
  data.setUint8(0, 1);
  data.setUint16(2, sequence, Endian.little);
  data.setUint32(4, timestampUs, Endian.little);
  final angle = tiltDegrees * math.pi / 180;
  data.setInt16(
    8,
    (math.sin(angle) * gravityG / 0.000122).round(),
    Endian.little,
  );
  data.setInt16(
    12,
    (math.cos(angle) * gravityG / 0.000122).round(),
    Endian.little,
  );
  data.setInt16(14, moving ? 2857 : 0, Endian.little); // About 50 dps.
  return data.buffer.asUint8List();
}
