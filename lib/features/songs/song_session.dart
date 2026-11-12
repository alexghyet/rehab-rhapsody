import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/song_audio_player.dart';
import 'song.dart';
import 'song_catalog.dart';
import 'song_game.dart';

/// The backing recording is the clock. Interpolation only bridges short gaps
/// between position events; stalled audio cannot silently advance the chart.
class SongSession extends ChangeNotifier {
  SongSession({required this.audio, Duration Function()? now})
    : _now = now ?? (Stopwatch()..start()).readElapsed,
      _song = demoSongs.first,
      _game = SongGame(demoSongs.first) {
    _positions = audio.positions.listen(_positionChanged, onError: _failed);
    _completions = audio.completions.listen(
      (_) => _complete(),
      onError: _failed,
    );
  }

  final SongAudioPlayer audio;
  final Duration Function() _now;
  late final StreamSubscription<Duration> _positions;
  late final StreamSubscription<void> _completions;
  SongDefinition _song;
  SongGame _game;
  Duration _position = Duration.zero;
  Duration _anchor = Duration.zero;
  Duration? _anchorAt;
  Duration? _lastProgressAt;
  Duration _lastReported = Duration.zero;
  Timer? _ticker;
  bool _running = false;
  bool _starting = false;
  bool _disposed = false;
  int _generation = 0;
  String? _loadedAsset;
  String? _message;

  SongDefinition get song => _song;
  SongGame get game => _game;
  Duration get position => _position;
  bool get running => _running;
  bool get starting => _starting;
  String? get message => _message;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> start(double volume) async {
    if (_disposed || _starting) return false;
    if (_running) return true;
    if (_game.isComplete) reset();
    final generation = ++_generation;
    _starting = true;
    _message = null;
    _changed();
    try {
      if (_loadedAsset != _song.backingAsset) {
        await audio.load(_song.backingAsset);
        if (_disposed || generation != _generation) return false;
        _loadedAsset = _song.backingAsset;
      }
      await audio.seek(_position);
      if (_disposed || generation != _generation) return false;
      await audio.setVolume(volume.clamp(0.0, 1.0));
      if (_disposed || generation != _generation) return false;
      await audio.play();
      if (_disposed || generation != _generation) return false;
      _starting = false;
      _running = true;
      _anchor = _position;
      _anchorAt = _now();
      _lastReported = _position;
      _lastProgressAt = _anchorAt;
      _ticker = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) => _tick(),
      );
      _changed();
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation) _failed(error);
      return false;
    }
  }

  void _positionChanged(Duration position) {
    if (_disposed || !_running || position < _lastReported) return;
    final bounded = position > _song.duration ? _song.duration : position;
    if (bounded > _lastReported) {
      _lastProgressAt = _now();
      _lastReported = bounded;
      _anchor = bounded;
      _anchorAt = _now();
      _tick();
    }
  }

  void _tick() {
    if (!_running || _disposed) return;
    final now = _now();
    if (now - _lastProgressAt! > const Duration(seconds: 2)) {
      _failed(StateError('Backing audio stopped advancing'));
      return;
    }
    final elapsed = now - _anchorAt!;
    final boundedElapsed = elapsed > const Duration(milliseconds: 350)
        ? const Duration(milliseconds: 350)
        : elapsed;
    final next = _anchor + boundedElapsed;
    if (next > _position) {
      _position = next > _song.duration ? _song.duration : next;
      _game.update(_position);
    }
    _changed();
  }

  SongHit? hit() {
    if (!_running || _disposed) return null;
    _tick();
    if (!_running) return null;
    final hit = _game.hit(_position);
    _changed();
    return hit;
  }

  /// Called by the coordinator while processing a clock/target update. It
  /// deliberately neither ticks nor notifies, avoiding recursive clock events.
  SongHit? hitDue() {
    if (!_running || _disposed) return null;
    return _game.hitDue(_position);
  }

  void pause() {
    if (_disposed) return;
    ++_generation;
    _running = false;
    _starting = false;
    _ticker?.cancel();
    _ticker = null;
    unawaited(audio.pause().catchError((Object _) {}));
    _changed();
  }

  void reset() {
    if (_disposed) return;
    pause();
    _position = Duration.zero;
    _anchor = Duration.zero;
    _anchorAt = null;
    _lastProgressAt = null;
    _lastReported = Duration.zero;
    _game.reset();
    _message = null;
    unawaited(audio.stop().catchError((Object _) {}));
    _changed();
  }

  void selectSong(SongDefinition song) {
    if (_disposed || song.id == _song.id) return;
    reset();
    _song = song;
    _game = SongGame(song);
    _changed();
  }

  void setVolume(double volume) {
    if (_disposed) return;
    unawaited(audio.setVolume(volume.clamp(0.0, 1.0)).catchError(_failed));
  }

  void _complete() {
    if (_disposed || !_running) return;
    _position = _song.duration;
    _game.update(_position);
    pause();
  }

  void _failed(Object error) {
    if (_disposed) return;
    _message = 'Song audio stopped. Tap Play to try again.';
    pause();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _ticker?.cancel();
    unawaited(_positions.cancel());
    unawaited(_completions.cancel());
    unawaited(audio.dispose().catchError((Object _) {}));
    super.dispose();
  }
}

extension on Stopwatch {
  Duration readElapsed() => elapsed;
}
