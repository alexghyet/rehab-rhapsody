import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/asset_song_audio_player.dart';
import 'package:rehab_rhapsody/features/audio/song_audio_player.dart';

void main() {
  test(
    'pause during load cancels queued play; explicit resume works',
    () async {
      final driver = FakeSongAudioDriver()..loadGate = Completer<void>();
      final player = AssetSongAudioPlayer(driver: driver);
      final loading = player.load('audio/songs/first.wav');
      await driver.loadStarted.future;
      final playing = player.play();
      final pausing = player.pause();
      expect(driver.commands.last, 'pause');
      driver.loadGate!.complete();
      await Future.wait([loading, playing, pausing]);
      expect(driver.commands.where((command) => command == 'play'), isEmpty);

      await player.play();
      expect(driver.commands.where((command) => command == 'play').length, 1);
      await player.dispose();
    },
  );

  test('stop during platform resume drains any late playback', () async {
    final driver = FakeSongAudioDriver()..playGate = Completer<void>();
    final player = AssetSongAudioPlayer(driver: driver);
    await player.load('audio/songs/first.wav');
    final playing = player.play();
    await driver.playStarted.future;
    final stopping = player.stop();
    expect(driver.commands.last, 'stop');
    driver.playGate!.complete();
    await Future.wait([playing, stopping]);
    expect(driver.playing, isFalse);
    expect(driver.commands.last, 'stop');
    await player.dispose();
  });

  test(
    'changing songs cancels old start, forwards only active events',
    () async {
      final driver = FakeSongAudioDriver()..loadGate = Completer<void>();
      final player = AssetSongAudioPlayer(driver: driver);
      final positions = <Duration>[];
      var completions = 0;
      player.positions.listen(positions.add);
      player.completions.listen((_) => ++completions);

      final firstLoad = player.load('audio/songs/first.wav');
      await driver.loadStarted.future;
      final oldPlay = player.play();
      final secondLoad = player.load('audio/songs/second.wav');
      driver.positionEvents.add(const Duration(seconds: 20));
      driver.completionEvents.add(null);
      driver.loadGate!.complete();
      await Future.wait([firstLoad, oldPlay, secondLoad]);
      expect(driver.commands.where((command) => command == 'play'), isEmpty);
      expect(positions, isEmpty);
      expect(completions, 0);

      await player.play();
      driver.positionEvents.add(const Duration(seconds: 1));
      expect(positions, [const Duration(seconds: 1)]);
      await player.pause();
      driver.positionEvents.add(const Duration(seconds: 2));
      driver.completionEvents.add(null);
      expect(positions.length, 1);
      expect(completions, 0);
      await player.play();
      driver.completionEvents.add(null);
      driver.completionEvents.add(null);
      expect(completions, 1);
      await player.dispose();
    },
  );

  test('same song load preserves position across pause and resume', () async {
    final driver = FakeSongAudioDriver();
    final player = AssetSongAudioPlayer(driver: driver);
    await player.load('audio/songs/first.wav');
    await player.play();
    await player.pause();
    await player.load('audio/songs/first.wav');
    await player.play();
    expect(
      driver.commands.where((command) => command.startsWith('load:')).length,
      1,
    );
    expect(
      driver.commands.where((command) => command.startsWith('seek:')),
      isEmpty,
    );
    await player.seek(const Duration(seconds: 3));
    expect(driver.commands.last, 'seek:3000000');
    await player.dispose();
  });

  test(
    'failed loads can retry and do not leave a playable old source',
    () async {
      final driver = FakeSongAudioDriver();
      final player = AssetSongAudioPlayer(driver: driver);
      await player.load('audio/songs/first.wav');
      driver.failLoad = true;
      await expectLater(
        player.load('audio/songs/second.wav'),
        throwsStateError,
      );
      await expectLater(player.play(), throwsStateError);
      await player.load('audio/songs/second.wav');
      await player.play();
      expect(driver.playing, isTrue);
      await player.dispose();
    },
  );

  test('dispose during load cancels sound and releases driver once', () async {
    final driver = FakeSongAudioDriver()..loadGate = Completer<void>();
    final player = AssetSongAudioPlayer(driver: driver);
    final loading = player.load('audio/songs/first.wav');
    await driver.loadStarted.future;
    final playing = player.play();
    final disposing = player.dispose();
    driver.loadGate!.complete();
    await Future.wait([loading, playing, disposing]);
    await player.dispose();
    expect(driver.commands.where((command) => command == 'play'), isEmpty);
    expect(driver.commands.where((command) => command == 'dispose').length, 1);
    await expectLater(player.play(), throwsStateError);
    await expectLater(player.load('audio/songs/first.wav'), throwsStateError);
  });

  test(
    'volume bounds and invalid positions are handled before platform calls',
    () async {
      final driver = FakeSongAudioDriver();
      final player = AssetSongAudioPlayer(driver: driver);
      await player.setVolume(2);
      expect(driver.commands.last, 'volume:1.0');
      await expectLater(player.setVolume(double.nan), throwsArgumentError);
      await expectLater(
        player.seek(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      await player.dispose();
    },
  );
}

class FakeSongAudioDriver implements SongAudioDriver {
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final completionEvents = StreamController<void>.broadcast(sync: true);
  final loadStarted = Completer<void>();
  final playStarted = Completer<void>();
  final commands = <String>[];
  Completer<void>? loadGate;
  Completer<void>? playGate;
  bool playing = false;
  bool failLoad = false;

  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<void> get completions => completionEvents.stream;
  @override
  Future<void> load(String assetPath) async {
    commands.add('load:$assetPath');
    if (!loadStarted.isCompleted) loadStarted.complete();
    await loadGate?.future;
    if (failLoad) {
      failLoad = false;
      throw StateError('Could not load song');
    }
  }

  @override
  Future<void> play() async {
    commands.add('play');
    if (!playStarted.isCompleted) playStarted.complete();
    await playGate?.future;
    playing = true;
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    playing = false;
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    playing = false;
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek:${position.inMicroseconds}');
  }

  @override
  Future<void> setVolume(double volume) async => commands.add('volume:$volume');
  @override
  Future<void> dispose() async {
    commands.add('dispose');
    await positionEvents.close();
    await completionEvents.close();
  }
}
