import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/asset_song_audio_player.dart';

void main() {
  test(
    'platform stream errors reach the session instead of escaping',
    () async {
      final player = _FakeAudioPlayer();
      final driver = AudioplayersSongDriver(createPlayer: () => player);
      final errors = <Object>[];
      final subscription = driver.completions.listen(
        (_) {},
        onError: errors.add,
      );
      await driver.load('audio/songs/test.wav');
      await driver.play();

      final failure = StateError('Backing playback failed');
      player._completions.addError(failure);
      expect(errors, [failure]);
      await subscription.cancel();
      await driver.dispose();
    },
  );

  testWidgets(
    'slow position responses stay bounded and paused results are discarded',
    (tester) async {
      final player = _FakeAudioPlayer();
      final driver = AudioplayersSongDriver(createPlayer: () => player);
      final positions = <Duration>[];
      final subscription = driver.positions.listen(positions.add);
      await driver.load('audio/songs/test.wav');
      await driver.play();

      await tester.pump(const Duration(milliseconds: 50));
      expect(player.queries, hasLength(1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(player.queries, hasLength(1));

      await driver.pause();
      player.queries.single.complete(const Duration(milliseconds: 500));
      await tester.pump();
      expect(positions, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(player.queries, hasLength(1));

      await driver.play();
      await tester.pump(const Duration(milliseconds: 50));
      expect(player.queries, hasLength(2));
      player.queries.last.complete(const Duration(milliseconds: 600));
      await tester.pump();
      expect(positions, [const Duration(milliseconds: 600)]);
      await subscription.cancel();
      await driver.dispose();
    },
  );

  testWidgets(
    'a seek discards an older query and resumes from the new position',
    (tester) async {
      final player = _FakeAudioPlayer();
      final driver = AudioplayersSongDriver(createPlayer: () => player);
      final positions = <Duration>[];
      final subscription = driver.positions.listen(positions.add);
      await driver.load('audio/songs/test.wav');
      await driver.play();
      await tester.pump(const Duration(milliseconds: 50));

      await driver.seek(const Duration(seconds: 2));
      player.queries.single.complete(const Duration(seconds: 9));
      await tester.pump();
      expect(positions, isEmpty);
      await tester.pump(const Duration(milliseconds: 50));
      player.queries.last.complete(const Duration(milliseconds: 2050));
      await tester.pump();
      expect(positions, [const Duration(milliseconds: 2050)]);
      await subscription.cancel();
      await driver.dispose();
    },
  );
}

/// Only the platform operations used by the driver are implemented. Constructing
/// a real AudioPlayer here would initialize a native plugin before injection.
class _FakeAudioPlayer implements AudioPlayer {
  final queries = <Completer<Duration?>>[];
  final _completions = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get onPlayerComplete => _completions.stream;

  @override
  set positionUpdater(PositionUpdater? value) {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> setAudioContext(AudioContext context) async {}

  @override
  Future<void> setSource(Source source) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<Duration?> getDuration() async => const Duration(seconds: 30);

  @override
  Future<Duration?> getCurrentPosition() {
    final result = Completer<Duration?>();
    queries.add(result);
    return result.future;
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() => _completions.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
