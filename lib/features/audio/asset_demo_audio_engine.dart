import 'dart:async';

import 'package:audio_session/audio_session.dart' as session;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../home/home_options.dart';
import 'demo_audio_engine.dart';

/// Plays the bundled, original synthesized instrument samples monophonically.
///
/// Generation checks separate source preparation from resume: an old load
/// cannot start a voice after pause/disconnect. Stop is sent immediately and
/// repeated after any in-flight preparation finishes.
class AssetDemoAudioEngine extends DemoAudioEngine {
  AssetDemoAudioEngine({DemoAudioDriver? driver})
    : _driver = driver ?? AudioplayersDemoDriver() {
    _interruptionSubscription = _driver.interruptions.listen(
      (_) => _interrupted(),
      onError: (Object error, StackTrace stack) => _interrupted(error, stack),
    );
  }

  final DemoAudioDriver _driver;
  final _interruptions = StreamController<void>.broadcast(sync: true);
  late final StreamSubscription<void> _interruptionSubscription;
  Future<void> _tail = Future<void>.value();
  Future<void>? _initializing;
  Future<void>? _disposing;
  bool _disposed = false;
  int _generation = 0;

  @override
  Stream<void> get interruptions => _interruptions.stream;

  void _interrupted([Object? error, StackTrace? stack]) {
    if (_disposed) return;
    // Invalidate synchronously before notifying the session coordinator.
    final stopping = stop();
    if (error == null) {
      _interruptions.add(null);
    } else {
      _interruptions.addError(error, stack);
    }
    unawaited(
      stopping.catchError((Object error, StackTrace stack) {
        if (!_interruptions.isClosed) _interruptions.addError(error, stack);
      }),
    );
  }

  Future<void> _enqueue(Future<void> Function() command) {
    final next = _tail.then((_) => command());
    // Keep later stop/dispose available even if an earlier platform call fails.
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<void> initialize() {
    if (_disposed) return Future<void>.error(StateError('Audio is disposed'));
    return _initializing ??= _enqueue(() async {
      try {
        await _driver.initialize();
      } catch (_) {
        // Keep the successful initialization memoized, but let a later Play
        // tap retry a failed platform/session initialization.
        _initializing = null;
        rethrow;
      }
    });
  }

  @override
  Future<void> play({
    required int midiNote,
    required Instrument instrument,
    required double volume,
  }) {
    if (_disposed) return Future<void>.error(StateError('Audio is disposed'));
    if (!volume.isFinite) {
      return Future<void>.error(ArgumentError.value(volume, 'volume'));
    }
    final assetPath = demoAudioAsset(instrument, midiNote);
    final initialization = initialize();
    final generation = ++_generation;
    return _enqueue(() async {
      await initialization;
      if (_disposed || generation != _generation) return;
      await _driver.stop();
      if (_disposed || generation != _generation) return;
      await _driver.prepare(assetPath);
      if (_disposed || generation != _generation) return;
      await _driver.setVolume(volume.clamp(0.0, 1.0));
      if (_disposed || generation != _generation) return;
      await _driver.resume();
      if (_disposed || generation != _generation) await _driver.stop();
    });
  }

  @override
  Future<void> stop() {
    ++_generation;
    if (_disposed) return _disposing ?? Future<void>.value();
    // Do not wait for a slow prepare() before asking the active voice to stop.
    final immediateStop = _driver.stop();
    // Register both error handlers immediately. The final stop also ensures a
    // late platform resume already in flight cannot leave sound running.
    final drainStop = _enqueue(_driver.stop);
    return Future.wait<void>([immediateStop, drainStop]).then((_) {});
  }

  @override
  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    ++_generation;
    _disposed = true;
    final immediateStop = _driver.stop();
    final drain = _enqueue(() async {
      await _interruptionSubscription.cancel();
      await _driver.dispose();
      await _interruptions.close();
    });
    return _disposing = Future.wait<void>([immediateStop, drain]).then((_) {});
  }
}

/// Native/web adapter with one prepared player per short sample.
///
/// Sources are loaded before the session starts and retained with ReleaseMode.stop.
/// A hit only selects an already prepared player, sets gain, and resumes it.
class AudioplayersDemoDriver implements DemoAudioDriver {
  AudioplayersDemoDriver({
    DemoSamplePlayer Function(String assetPath)? createPlayer,
    this.configureSession,
  }) : _createPlayer = createPlayer ?? ((_) => AudioplayersSamplePlayer());

  final DemoSamplePlayer Function(String assetPath) _createPlayer;
  final Future<void> Function()? configureSession;
  final Map<String, DemoSamplePlayer> _players = {};
  DemoSamplePlayer? _active;
  bool _initialized = false;
  final _interruptions = StreamController<void>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  DemoSamplePlayer get _activePlayer =>
      _active ?? (throw StateError('Prepare a sample before playing it'));

  @override
  Stream<void> get interruptions => _interruptions.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (configureSession != null) {
        await configureSession!();
      } else if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.android)) {
        final audioSession = await session.AudioSession.instance;
        await audioSession.configure(
          const session.AudioSessionConfiguration.music(),
        );
        _subscriptions.add(
          audioSession.interruptionEventStream.listen((event) {
            if (event.begin) _interruptions.add(null);
          }, onError: _interruptions.addError),
        );
        _subscriptions.add(
          audioSession.becomingNoisyEventStream.listen(
            (_) => _interruptions.add(null),
            onError: _interruptions.addError,
          ),
        );
      }
      // Bound simultaneous native player preparation. The full bank is only
      // about 1.7 MB, and no sources are reloaded when the instrument changes.
      for (final instrument in Instrument.values) {
        for (var offset = 0; offset < demoMidiNotes.length; offset += 4) {
          await Future.wait([
            for (final midi in demoMidiNotes.skip(offset).take(4))
              _prepareSample(demoAudioAsset(instrument, midi)),
          ]);
        }
      }
      _initialized = true;
    } catch (_) {
      try {
        await _tearDownPlayers();
      } catch (_) {
        // Preserve the preparation error and allow a later initialization retry.
      }
      rethrow;
    }
  }

  Future<void> _prepareSample(String assetPath) async {
    final player = _createPlayer(assetPath);
    _players[assetPath] = player;
    _subscriptions.add(
      player.interruptions.listen(
        (_) {
          if (identical(player, _active)) _interruptions.add(null);
        },
        onError: (Object error, StackTrace stack) {
          if (identical(player, _active)) _interruptions.addError(error, stack);
        },
      ),
    );
    await player.initialize(assetPath);
  }

  @override
  Future<void> prepare(String assetPath) async {
    if (!_initialized) throw StateError('Initialize the audio driver first');
    _active =
        _players[assetPath] ??
        (throw ArgumentError.value(assetPath, 'assetPath', 'Unknown sample'));
  }

  @override
  Future<void> setVolume(double volume) => _activePlayer.setVolume(volume);

  @override
  Future<void> resume() => _activePlayer.resume();

  @override
  Future<void> stop() async {
    await _active?.stop();
  }

  Future<void> _tearDownPlayers() async {
    _initialized = false;
    _active = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final players = _players.values.toList();
    _players.clear();
    await Future.wait(players.map((player) => player.dispose()));
  }

  @override
  Future<void> dispose() async {
    await _tearDownPlayers();
    await _interruptions.close();
  }
}

/// A prepared sample player, injectable to verify caching without a device.
abstract interface class DemoSamplePlayer {
  Stream<void> get interruptions;
  Future<void> initialize(String assetPath);
  Future<void> setVolume(double volume);
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersSamplePlayer implements DemoSamplePlayer {
  final AudioPlayer _player = AudioPlayer()..positionUpdater = null;

  @override
  Stream<void> get interruptions => _player.onPlayerStateChanged
      .where((state) => state == PlayerState.paused)
      .map((_) {});

  @override
  Future<void> initialize(String assetPath) async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setAudioContext(
      AudioContextConfig(respectSilence: false).build(),
    );
    await _player.setSource(AssetSource(assetPath));
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
