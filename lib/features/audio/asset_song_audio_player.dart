import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'song_audio_player.dart';

/// Serialized backing playback with immediate cancellation of pending starts.
/// The note engine configures the shared native audio session first; the demo
/// coordinator pauses both players when that session is interrupted.
class AssetSongAudioPlayer extends SongAudioPlayer {
  AssetSongAudioPlayer({SongAudioDriver? driver})
    : _driver = driver ?? AudioplayersSongDriver() {
    _positionSubscription = _driver.positions.listen((position) {
      if (!_disposed && _loadedAsset != null && _playing) {
        _positions.add(position);
      }
    }, onError: _positions.addError);
    _completionSubscription = _driver.completions.listen((_) {
      if (_disposed || !_playing || _loadedAsset == null) return;
      _playing = false;
      _completions.add(null);
    }, onError: _completions.addError);
  }

  final SongAudioDriver _driver;
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _completions = StreamController<void>.broadcast(sync: true);
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<void> _completionSubscription;
  Future<void> _tail = Future<void>.value();
  Future<void>? _loading;
  Future<void>? _disposing;
  String? _requestedAsset;
  String? _loadedAsset;
  bool _disposed = false;
  bool _playing = false;
  int _generation = 0;
  int _sourceGeneration = 0;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<void> get completions => _completions.stream;

  Future<void> _enqueue(Future<void> Function() command) {
    final next = _tail.then((_) => command());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<void> load(String assetPath) {
    if (_disposed) return Future.error(StateError('Song audio is disposed'));
    if (assetPath.isEmpty) {
      return Future.error(ArgumentError('Empty song asset'));
    }
    if (_requestedAsset == assetPath) {
      if (_loading != null) return _loading!;
      if (_loadedAsset == assetPath) return Future<void>.value();
    }
    ++_generation;
    final sourceGeneration = ++_sourceGeneration;
    _playing = false;
    _requestedAsset = assetPath;
    _loadedAsset = null;
    final immediateStop = _driver.stop();
    final command = _enqueue(() async {
      await immediateStop;
      if (_disposed || sourceGeneration != _sourceGeneration) return;
      await _driver.load(assetPath);
      if (_disposed || sourceGeneration != _sourceGeneration) return;
      _loadedAsset = assetPath;
    });
    return _loading = Future.wait<void>([immediateStop, command])
        .then((_) {})
        .whenComplete(() {
          if (sourceGeneration == _sourceGeneration) _loading = null;
        });
  }

  @override
  Future<void> play() {
    if (_disposed) return Future.error(StateError('Song audio is disposed'));
    final generation = ++_generation;
    final loading = _loading;
    return _enqueue(() async {
      await loading;
      if (_disposed || generation != _generation) return;
      if (_loadedAsset == null) throw StateError('Load a song before playing');
      _playing = true;
      try {
        await _driver.play();
      } catch (_) {
        _playing = false;
        rethrow;
      }
      if (_disposed || generation != _generation) {
        _playing = false;
        await _driver.pause();
      }
    });
  }

  @override
  Future<void> pause() {
    ++_generation;
    _playing = false;
    if (_disposed) return _disposing ?? Future<void>.value();
    final immediatePause = _driver.pause();
    final drainPause = _enqueue(_driver.pause);
    return Future.wait<void>([immediatePause, drainPause]).then((_) {});
  }

  @override
  Future<void> stop() {
    ++_generation;
    _playing = false;
    if (_disposed) return _disposing ?? Future<void>.value();
    final immediateStop = _driver.stop();
    final drainStop = _enqueue(_driver.stop);
    return Future.wait<void>([immediateStop, drainStop]).then((_) {});
  }

  @override
  Future<void> seek(Duration position) {
    if (_disposed) return Future.error(StateError('Song audio is disposed'));
    if (position.isNegative) {
      return Future.error(ArgumentError.value(position, 'position'));
    }
    final sourceGeneration = _sourceGeneration;
    return _enqueue(() async {
      if (_disposed || sourceGeneration != _sourceGeneration) return;
      if (_loadedAsset == null) throw StateError('Load a song before seeking');
      await _driver.seek(position);
    });
  }

  @override
  Future<void> setVolume(double volume) {
    if (_disposed) return Future.error(StateError('Song audio is disposed'));
    if (!volume.isFinite) {
      return Future.error(ArgumentError.value(volume, 'volume'));
    }
    return _enqueue(() async {
      if (!_disposed) await _driver.setVolume(volume.clamp(0.0, 1.0));
    });
  }

  @override
  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    ++_generation;
    ++_sourceGeneration;
    _disposed = true;
    _playing = false;
    final immediateStop = _driver.stop();
    final drain = _enqueue(() async {
      await _positionSubscription.cancel();
      await _completionSubscription.cancel();
      await _driver.dispose();
      await _positions.close();
      await _completions.close();
    });
    return _disposing = Future.wait<void>([immediateStop, drain]).then((_) {});
  }
}

class AudioplayersSongDriver implements SongAudioDriver {
  AudioplayersSongDriver({AudioPlayer Function()? createPlayer})
    : _createPlayer = createPlayer ?? AudioPlayer.new;

  final AudioPlayer Function() _createPlayer;
  AudioPlayer? _player;
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _completions = StreamController<void>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  double _volume = 1;
  int _sourceGeneration = 0;
  int _positionGeneration = 0;
  Duration _lastPosition = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _polling = false;
  Timer? _positionTimer;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<void> get completions => _completions.stream;

  AudioPlayer get _active =>
      _player ?? (throw StateError('Load a song before using the player'));

  @override
  Future<void> load(String assetPath) async {
    final sourceGeneration = ++_sourceGeneration;
    ++_positionGeneration;
    _playing = false;
    _lastPosition = Duration.zero;
    _duration = null;
    // A different source gets a different platform player and subscriptions.
    // Late events from the old source cannot become the new song's clock.
    await _disposePlayer();
    final player = _player = _createPlayer()..positionUpdater = null;
    _subscriptions.add(
      player.onPlayerComplete.listen(
        (_) {
          if (!_playing || sourceGeneration != _sourceGeneration) return;
          // A queued completion from before a restart must not end a new attempt.
          // Position is observed every 50 ms; allow the final poll to precede EOF.
          final duration = _duration;
          if (duration != null &&
              _lastPosition < duration - const Duration(milliseconds: 300)) {
            return;
          }
          _playing = false;
          _positionTimer?.cancel();
          _completions.add(null);
        },
        onError: (Object error, StackTrace stack) {
          if (_playing && sourceGeneration == _sourceGeneration) {
            _completions.addError(error, stack);
          }
        },
      ),
    );
    await _active.setReleaseMode(ReleaseMode.stop);
    await _active.setAudioContext(
      AudioContextConfig(respectSilence: false).build(),
    );
    await _active.setSource(AssetSource(assetPath));
    await _active.setVolume(_volume);
    _duration = await _active.getDuration();
  }

  @override
  Future<void> play() async {
    ++_positionGeneration;
    _playing = true;
    try {
      await _active.resume();
      if (_playing) {
        _positionTimer?.cancel();
        _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          unawaited(_pollPosition());
        });
      }
    } catch (_) {
      _playing = false;
      rethrow;
    }
  }

  Future<void> _pollPosition() async {
    final generation = _positionGeneration;
    final source = _sourceGeneration;
    final player = _player;
    if (!_playing || _polling || player == null) return;
    // A slow platform response must not build a queue of overlapping polls.
    // Session/source generations still discard an old response after a seek.
    _polling = true;
    try {
      final position = await player.getCurrentPosition();
      if (!_playing ||
          generation != _positionGeneration ||
          source != _sourceGeneration ||
          position == null ||
          position < _lastPosition) {
        return;
      }
      _lastPosition = position;
      // Check and synchronous delivery happen together. No stale stream event
      // can wait between the generation check and a restart/seek.
      _positions.add(position);
    } catch (error, stack) {
      if (_playing && generation == _positionGeneration) {
        _positions.addError(error, stack);
      }
    } finally {
      _polling = false;
    }
  }

  @override
  Future<void> pause() async {
    _positionTimer?.cancel();
    ++_positionGeneration;
    _playing = false;
    await _player?.pause();
  }

  @override
  Future<void> stop() async {
    _positionTimer?.cancel();
    ++_positionGeneration;
    _playing = false;
    _lastPosition = Duration.zero;
    await _player?.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    ++_positionGeneration;
    _lastPosition = position;
    await _active.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _player?.setVolume(volume);
  }

  Future<void> _disposePlayer() async {
    _positionTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player?.dispose();
    _player = null;
  }

  @override
  Future<void> dispose() async {
    ++_sourceGeneration;
    ++_positionGeneration;
    _playing = false;
    await _disposePlayer();
    await _positions.close();
    await _completions.close();
  }
}
