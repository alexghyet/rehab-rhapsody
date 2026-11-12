import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/asset_demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/audio/demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';

void main() {
  test(
    'all instrument samples are ready before hits, with no reloads',
    () async {
      final players = <String, FakeSamplePlayer>{};
      final driver = AudioplayersDemoDriver(
        createPlayer: (path) => players[path] = FakeSamplePlayer(),
        configureSession: () async {},
      );
      final engine = AssetDemoAudioEngine(driver: driver);
      await engine.initialize();

      expect(players.length, Instrument.values.length * demoMidiNotes.length);
      expect(players.values.every((player) => player.loads == 1), isTrue);
      for (final instrument in Instrument.values) {
        for (final midi in [60, 60, 64, 72]) {
          await engine.play(
            midiNote: midi,
            instrument: instrument,
            volume: 0.6,
          );
          // Only one prepared sample may be sounding at a time.
          expect(players.values.where((player) => player.playing).length, 1);
        }
      }
      expect(players.values.every((player) => player.loads == 1), isTrue);
      for (final instrument in Instrument.values) {
        expect(players[demoAudioAsset(instrument, 60)]!.starts, 2);
      }
      await engine.stop();
      expect(players.values.any((player) => player.playing), isFalse);
      await engine.dispose();
      expect(players.values.every((player) => player.disposals == 1), isTrue);
    },
  );

  test('a failed preload disposes its partial bank and can retry', () async {
    final players = <FakeSamplePlayer>[];
    var fail = true;
    final driver = AudioplayersDemoDriver(
      createPlayer: (_) {
        final player = FakeSamplePlayer()..failLoad = fail;
        players.add(player);
        fail = false;
        return player;
      },
      configureSession: () async {},
    );
    final engine = AssetDemoAudioEngine(driver: driver);
    await expectLater(engine.initialize(), throwsStateError);
    final failedBankSize = players.length;
    expect(failedBankSize, 4);
    expect(players.every((player) => player.disposals == 1), isTrue);

    await engine.initialize();
    expect(players.length, failedBankSize + 32);
    await engine.play(midiNote: 67, instrument: Instrument.piano, volume: 0.5);
    expect(players.where((player) => player.playing).length, 1);
    await engine.dispose();
    expect(players.every((player) => player.disposals == 1), isTrue);
  });
}

class FakeSamplePlayer implements DemoSamplePlayer {
  final _interruptions = StreamController<void>.broadcast();
  int loads = 0;
  int starts = 0;
  int disposals = 0;
  bool playing = false;
  bool failLoad = false;

  @override
  Stream<void> get interruptions => _interruptions.stream;
  @override
  Future<void> initialize(String assetPath) async {
    ++loads;
    if (failLoad) throw StateError('Could not prepare sample');
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> resume() async {
    playing = true;
    ++starts;
  }

  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> dispose() async {
    ++disposals;
    playing = false;
    await _interruptions.close();
  }
}
