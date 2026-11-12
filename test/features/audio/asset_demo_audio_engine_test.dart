import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/asset_demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/audio/demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';

void main() {
  test(
    'an interruption stream error cancels playback and reaches the caller',
    () async {
      final driver = FakeAudioDriver()..prepareGate = Completer<void>();
      final engine = AssetDemoAudioEngine(driver: driver);
      final errors = <Object>[];
      final subscription = engine.interruptions.listen(
        (_) {},
        onError: errors.add,
      );
      final playing = engine.play(
        midiNote: 60,
        instrument: Instrument.piano,
        volume: 0.5,
      );
      await driver.prepareStarted.future;

      final failure = StateError('Audio device unavailable');
      driver.interruptionEvents.addError(failure);
      expect(errors, [failure]);
      expect(driver.commands.last, 'stop');
      driver.prepareGate!.complete();
      await playing;
      await engine.stop();
      expect(driver.commands.where((command) => command == 'resume'), isEmpty);

      await subscription.cancel();
      await engine.dispose();
    },
  );

  test('a stop during source preparation prevents a late resume', () async {
    final driver = FakeAudioDriver()..prepareGate = Completer<void>();
    final engine = AssetDemoAudioEngine(driver: driver);
    final playing = engine.play(
      midiNote: 60,
      instrument: Instrument.piano,
      volume: 0.65,
    );
    await driver.prepareStarted.future;

    final stopping = engine.stop();
    expect(driver.commands.last, 'stop');
    driver.prepareGate!.complete();
    await Future.wait([playing, stopping]);

    expect(driver.commands.where((command) => command == 'resume'), isEmpty);
    await engine.dispose();
  });

  test(
    'only the newest request resumes after an older load finishes',
    () async {
      final driver = FakeAudioDriver()..prepareGate = Completer<void>();
      final engine = AssetDemoAudioEngine(driver: driver);
      final oldVoice = engine.play(
        midiNote: 60,
        instrument: Instrument.piano,
        volume: 0.65,
      );
      await driver.prepareStarted.future;
      final newVoice = engine.play(
        midiNote: 64,
        instrument: Instrument.flute,
        volume: 0.3,
      );
      driver.prepareGate!.complete();
      await Future.wait([oldVoice, newVoice]);

      expect(driver.commands.where((command) => command == 'resume').length, 1);
      expect(driver.commands, contains('prepare:audio/demo/flute_64.wav'));
      expect(driver.commands, contains('volume:0.3'));
      await engine.dispose();
    },
  );

  test(
    'an interruption invalidates a pending voice without auto resume',
    () async {
      final driver = FakeAudioDriver()..prepareGate = Completer<void>();
      final engine = AssetDemoAudioEngine(driver: driver);
      final interruption = engine.interruptions.first;
      final playing = engine.play(
        midiNote: 67,
        instrument: Instrument.strings,
        volume: 0.8,
      );
      await driver.prepareStarted.future;

      driver.interruptionEvents.add(null);
      await interruption;
      driver.prepareGate!.complete();
      await playing;
      await engine.stop();

      expect(driver.commands.where((command) => command == 'resume'), isEmpty);
      await engine.dispose();
    },
  );

  test(
    'dispose during load cannot start sound and releases driver once',
    () async {
      final driver = FakeAudioDriver()..prepareGate = Completer<void>();
      final engine = AssetDemoAudioEngine(driver: driver);
      final playing = engine.play(
        midiNote: 72,
        instrument: Instrument.drums,
        volume: 1,
      );
      await driver.prepareStarted.future;

      final disposing = engine.dispose();
      driver.prepareGate!.complete();
      await Future.wait([playing, disposing]);
      await engine.dispose();

      expect(driver.commands.where((command) => command == 'resume'), isEmpty);
      expect(
        driver.commands.where((command) => command == 'dispose').length,
        1,
      );
      await expectLater(
        engine.play(midiNote: 60, instrument: Instrument.piano, volume: 0.5),
        throwsStateError,
      );
    },
  );

  test('a failed prepare does not poison later playback or stop', () async {
    final driver = FakeAudioDriver()..failNextPrepare = true;
    final engine = AssetDemoAudioEngine(driver: driver);
    await expectLater(
      engine.play(midiNote: 60, instrument: Instrument.piano, volume: 0.5),
      throwsStateError,
    );

    await engine.play(midiNote: 62, instrument: Instrument.flute, volume: 0.5);
    expect(driver.commands.where((command) => command == 'resume').length, 1);
    await engine.stop();
    await engine.dispose();
  });

  test('a failed initialization can be retried by a later Play tap', () async {
    final driver = FakeAudioDriver()..failNextInitialization = true;
    final engine = AssetDemoAudioEngine(driver: driver);

    // Settings/connection changes may request stop before initialization.
    await engine.stop();
    expect(
      driver.commands.where((command) => command == 'initialize'),
      isEmpty,
    );
    await expectLater(engine.initialize(), throwsStateError);
    await engine.initialize();
    await engine.play(midiNote: 60, instrument: Instrument.piano, volume: 0.65);

    expect(
      driver.commands.where((command) => command == 'initialize').length,
      2,
    );
    expect(driver.commands.where((command) => command == 'resume').length, 1);
    await engine.dispose();
  });
}

class FakeAudioDriver implements DemoAudioDriver {
  final commands = <String>[];
  final interruptionEvents = StreamController<void>.broadcast(sync: true);
  final prepareStarted = Completer<void>();
  Completer<void>? prepareGate;
  bool failNextPrepare = false;
  bool failNextInitialization = false;

  @override
  Stream<void> get interruptions => interruptionEvents.stream;

  @override
  Future<void> initialize() async {
    commands.add('initialize');
    if (failNextInitialization) {
      failNextInitialization = false;
      throw StateError('Audio initialization failed');
    }
  }

  @override
  Future<void> prepare(String assetPath) async {
    commands.add('prepare:$assetPath');
    if (!prepareStarted.isCompleted) prepareStarted.complete();
    await prepareGate?.future;
    if (failNextPrepare) {
      failNextPrepare = false;
      throw StateError('Source could not be prepared');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    commands.add('volume:$volume');
  }

  @override
  Future<void> resume() async {
    commands.add('resume');
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
  }

  @override
  Future<void> dispose() async {
    commands.add('dispose');
    await interruptionEvents.close();
  }
}
