import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/song_audio_player.dart';
import 'package:rehab_rhapsody/features/songs/song_catalog.dart';
import 'package:rehab_rhapsody/features/songs/song_session.dart';

void main() {
  testWidgets(
    'due scoring inside a clock listener does not recursively notify',
    (tester) async {
      final h = _Harness();
      await h.session.start(0.5);
      var notifications = 0;
      h.session.addListener(() {
        notifications++;
        // A bounded assertion prevents an accidental notification loop from
        // hiding the regression behind an eventual stack overflow.
        expect(notifications, lessThan(4));
        h.session.hitDue();
      });
      final first = h.session.song.notes.first;
      h.audio.positionEvents.add(first.at);
      expect(notifications, 1);
      expect(h.session.game.hits, 1);
      expect(h.session.game.lastHit?.note.id, first.id);
      expect(h.session.hitDue(), isNull);
      expect(notifications, 1);
      // A due hit consumes only the last published media position; calling it
      // cannot advance the clock or emit another position notification.
      h.elapsed += const Duration(milliseconds: 100);
      expect(h.session.hitDue(), isNull);
      expect(h.session.position, first.at);
      expect(notifications, 1);
      h.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'due scoring waits for a published onset and refuses pause or disposal',
    (tester) async {
      final h = _Harness();
      expect(h.session.hitDue(), isNull);
      await h.session.start(0.5);
      final first = h.session.song.notes.first;
      h.audio.positionEvents.add(first.at - const Duration(microseconds: 1));
      expect(h.session.hitDue(), isNull);
      expect(h.session.game.hits, 0);
      h.session.pause();
      h.audio.positionEvents.add(first.at);
      expect(h.session.hitDue(), isNull);
      expect(h.session.game.hits, 0);
      await h.session.start(0.5);
      h.audio.positionEvents.add(first.at);
      expect(h.session.hitDue()?.note.id, first.id);
      expect(h.session.game.hits, 1);
      h.dispose();
      expect(h.session.hitDue(), isNull);
      await tester.pump();
    },
  );

  testWidgets(
    'chart follows audio, bridges short gaps, and pauses if stalled',
    (tester) async {
      final h = _Harness();
      expect(await h.session.start(0.5), isTrue);
      h.audio.positionEvents.add(const Duration(seconds: 3));
      await h.pump(tester, const Duration(milliseconds: 200));
      expect(h.session.position, const Duration(milliseconds: 3200));
      await h.pump(tester, const Duration(milliseconds: 600));
      expect(h.session.position, const Duration(milliseconds: 3350));
      h.audio.positionEvents.add(const Duration(seconds: 2));
      expect(h.session.position, const Duration(milliseconds: 3350));
      await h.pump(tester, const Duration(milliseconds: 1300));
      expect(h.session.running, isFalse);
      expect(h.session.message, contains('audio stopped'));
      h.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'pause freezes score and clock; resume seeks to the frozen position',
    (tester) async {
      final h = _Harness();
      await h.session.start(0.5);
      final first = h.session.song.notes.first;
      h.audio.positionEvents.add(first.at);
      expect(h.session.hit()?.note.id, first.id);
      expect(h.session.hit(), isNull);
      final score = h.session.game.score;
      h.session.pause();
      h.audio.positionEvents.add(first.at + const Duration(seconds: 1));
      await h.pump(tester, const Duration(seconds: 3));
      expect(h.session.position, first.at);
      expect(h.session.hit(), isNull);
      expect(h.session.game.score, score);
      await h.session.start(0.5);
      expect(h.audio.seeks.last, first.at);
      expect(h.audio.loads, hasLength(1));
      h.dispose();
      await tester.pump();
    },
  );

  testWidgets('cancelled load cannot start and the next start can retry', (
    tester,
  ) async {
    final h = _Harness();
    final gate = h.audio.loadGate = Completer<void>();
    final starting = h.session.start(0.5);
    h.session.pause();
    gate.complete();
    expect(await starting, isFalse);
    expect(h.audio.plays, 0);
    expect(h.session.running, isFalse);
    h.audio.loadGate = null;
    expect(await h.session.start(0.5), isTrue);
    expect(h.audio.plays, 1);
    h.dispose();
    await tester.pump();
  });

  testWidgets('completion retains results; replay and song change reset them', (
    tester,
  ) async {
    final h = _Harness();
    await h.session.start(0.5);
    h.audio.positionEvents.add(h.session.song.notes.first.at);
    h.session.hit();
    h.audio.completionEvents.add(null);
    expect(h.session.game.isComplete, isTrue);
    expect(h.session.running, isFalse);
    expect(h.session.game.hits, 1);
    await h.session.start(0.5);
    expect(h.session.game.hits, 0);
    expect(h.audio.seeks.last, Duration.zero);
    h.session.selectSong(demoSongs[1]);
    expect(h.session.running, isFalse);
    expect(h.session.position, Duration.zero);
    await h.session.start(0.5);
    expect(h.audio.loads.last, demoSongs[1].backingAsset);
    h.dispose();
    await tester.pump();
  });
}

class _Harness {
  _Harness() {
    session = SongSession(audio: audio, now: () => elapsed);
  }
  final audio = FakeSongAudio();
  late final SongSession session;
  Duration elapsed = Duration.zero;
  Future<void> pump(WidgetTester tester, Duration duration) async {
    elapsed += duration;
    await tester.pump(duration);
  }

  void dispose() => session.dispose();
}

class FakeSongAudio implements SongAudioPlayer {
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final completionEvents = StreamController<void>.broadcast(sync: true);
  final loads = <String>[];
  final seeks = <Duration>[];
  Completer<void>? loadGate;
  int plays = 0;
  int pauses = 0;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<void> get completions => completionEvents.stream;
  @override
  Future<void> load(String assetPath) async {
    loads.add(assetPath);
    await loadGate?.future;
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {
    await positionEvents.close();
    await completionEvents.close();
  }
}
