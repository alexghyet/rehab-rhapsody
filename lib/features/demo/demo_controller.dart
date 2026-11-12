import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/demo_audio_engine.dart';
import '../baton/baton_transport.dart';
import '../home/home_controller.dart';
import '../home/home_options.dart';
import '../motion/motion.dart';
import '../music/music_note.dart';
import '../songs/song.dart';
import '../songs/song_session.dart';

/// Coordinates transport, motion, audio and the existing session UI.
/// Demo movement ranges are musical controls, not rehabilitation calibration.
class DemoController extends ChangeNotifier {
  DemoController({
    required this.home,
    required this.transport,
    required this.audio,
    this.songSession,
    Duration Function()? now,
  }) : _now = now ?? (Stopwatch()..start()).elapsedDuration {
    _wasRunning = home.isRunning;
    _settings = _readSettings();
    home.addListener(_homeChanged);
    songSession?.addListener(_songChanged);
    _connectionSubscription = transport.connections.listen(_connectionChanged);
    _packetSubscription = transport.packets.listen(
      _packetReceived,
      onError: (Object _) =>
          _streamFailed('Motion stream interrupted. Reconnect the baton.'),
    );
    _interruptionSubscription = audio.interruptions.listen(
      (_) {
        pause();
        _message = 'Audio interrupted. Tap Play when you are ready.';
        _changed();
      },
      onError: (Object _) {
        pause();
        _message = 'Audio stopped. Tap Play to try again.';
        _changed();
      },
    );
  }

  static const guidedMelody = [
    60,
    60,
    67,
    67,
    69,
    69,
    67,
    65,
    65,
    64,
    64,
    62,
    62,
    60,
  ];
  final HomeController home;
  final BatonTransport transport;
  final DemoAudioEngine audio;
  final SongSession? songSession;
  final Duration Function() _now;
  final _guard = MotionStreamGuard();
  final _mapper = MotionMapper();
  final _history = <double>[];
  late final StreamSubscription<BatonConnection> _connectionSubscription;
  late final StreamSubscription<List<int>> _packetSubscription;
  late final StreamSubscription<void> _interruptionSubscription;
  Timer? _watchdog;
  Timer? _voiceTimer;
  Timer? _beatTimer;
  Duration? _lastReceived;
  Duration _lastPaint = Duration.zero;
  MotionMapping? _mapping;
  MotionFrame? _frame;
  bool _disposed = false;
  bool _wasRunning = false;
  bool _starting = false;
  Future<void>? _pendingStart;
  bool _live = false;
  bool _checkingTarget = false;
  double _targetCenter = 0.65;
  int _startGeneration = 0;
  int _padGeneration = 0;
  int _voiceGeneration = 0;
  int? _activeVoice;
  int _guidedIndex = 0;
  int _beat = 0;
  int _acceptedPackets = 0;
  int _rejectedPackets = 0;
  double _sampleRate = 0;
  String? _message;
  late (Instrument, PlayMode, double, double) _settings;

  BatonConnection get connection => transport.connection;
  bool get isLive => _live;
  bool get starting => _starting;
  List<double> get samples => List.unmodifiable(_history);
  MotionFrame? get latestFrame => _frame;
  MotionMapping? get mapping => _mapping;
  String? get message => _message;
  int get acceptedPackets => _acceptedPackets;
  int get rejectedPackets => _rejectedPackets;
  double get sampleRate => _sampleRate;
  int get beat => _beat;
  int get guidedStep => _guidedIndex;
  int get targetMidi => guidedMelody[_guidedIndex % guidedMelody.length];

  static const targetWidth = 0.10;
  static const minimumTargetCenter = targetWidth / 2;
  static const maximumTargetCenter = 1 - targetWidth / 2;
  double get targetCenter => _targetCenter;
  double get targetLow => _targetCenter - targetWidth / 2;
  double get targetHigh => _targetCenter + targetWidth / 2;

  /// A chart sample alone cannot keep earning notes while motion data stalls
  /// or while acceleration makes the cached gravity estimate unreliable.
  bool get hasFreshTargetReading {
    final received = _lastReceived;
    final frame = _frame;
    if (_disposed ||
        !connection.isConnected ||
        !_live ||
        _mapping == null ||
        received == null ||
        frame == null) {
      return false;
    }
    final age = _now() - received;
    final gravity = frame.accelerationG.magnitude;
    return age >= Duration.zero &&
        age <= const Duration(milliseconds: 250) &&
        gravity >= 0.5 &&
        gravity <= 1.5;
  }

  bool get inTarget =>
      hasFreshTargetReading &&
      _mapping!.normalizedLevel >= targetLow &&
      _mapping!.normalizedLevel <= targetHigh;

  void setTargetCenter(double value) {
    if (_disposed || !value.isFinite) return;
    final next = value.clamp(minimumTargetCenter, maximumTargetCenter);
    if (next == _targetCenter) return;
    _targetCenter = next;
    _changed();
  }

  void useCurrentPositionAsTarget() {
    if (hasFreshTargetReading) setTargetCenter(_mapping!.normalizedLevel);
  }

  (Instrument, PlayMode, double, double) _readSettings() =>
      (home.instrument, home.mode, home.volume, home.tempo);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _songChanged() {
    final song = songSession;
    if (_disposed || song == null) return;
    if (home.mode == PlayMode.song &&
        home.isRunning &&
        !song.running &&
        !song.starting) {
      home.pauseSession();
      _stopVoice();
      if (song.message != null) _message = song.message;
    }
    _hitSongTarget();
    _changed();
  }

  void _hitSongTarget() {
    if (_checkingTarget ||
        _disposed ||
        home.mode != PlayMode.song ||
        !home.isRunning ||
        !inTarget) {
      return;
    }
    _checkingTarget = true;
    try {
      final hit = songSession?.hitDue();
      if (hit != null) {
        unawaited(_play(hit.note.midiNote, 0.85));
      }
    } finally {
      _checkingTarget = false;
    }
  }

  void selectSong(SongDefinition song) {
    if (_disposed) return;
    pause();
    songSession?.selectSong(song);
    home.resetSession();
    _message = null;
    _changed();
  }

  Future<void> playSongNote() async {
    if (_disposed || home.mode != PlayMode.song || !home.isRunning) return;
    final hit = songSession?.hit();
    if (hit != null) await _play(hit.note.midiNote, 0.85);
  }

  Future<void> connect() async {
    if (_disposed) return;
    pause();
    _message = null;
    // The web transport opens its chooser before its first await.
    await transport.connect();
  }

  Future<void> disconnect() async {
    if (_disposed) return;
    pause();
    _resetStream();
    await transport.disconnect();
    _changed();
  }

  void _connectionChanged(BatonConnection connection) {
    if (_disposed) return;
    _resetStream();
    if (connection.isConnected) {
      _lastReceived = _now();
      _watchdog = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final last = _lastReceived;
        if (last != null && _now() - last > const Duration(seconds: 2)) {
          _streamFailed('No fresh motion readings. Reconnect the baton.');
        }
      });
    } else {
      pause();
    }
    _changed();
  }

  void _resetStream() {
    _watchdog?.cancel();
    _watchdog = null;
    _guard.reset();
    _mapper.reset();
    _lastReceived = null;
    _live = false;
    _history.clear();
    _mapping = null;
    _frame = null;
    _sampleRate = 0;
    _acceptedPackets = 0;
    _rejectedPackets = 0;
    _stopVoice();
  }

  void _packetReceived(List<int> packet) {
    if (_disposed || !connection.isConnected) return;
    final received = _now();
    late MotionFrame frame;
    try {
      frame = MotionPacketDecoder.decode(packet);
    } on FormatException {
      ++_rejectedPackets;
      return;
    }
    if (!_guard.accept(frame, received)) {
      ++_rejectedPackets;
      if (_guard.isExpired) {
        _streamFailed('Motion stream expired. Reconnect the baton.');
      }
      return;
    }
    final previous = _frame;
    if (previous != null) {
      final delta = (frame.timestampUs - previous.timestampUs) & 0xffffffff;
      final rate = 1000000 / delta;
      _sampleRate = _sampleRate == 0 ? rate : 0.8 * _sampleRate + 0.2 * rate;
    }
    _frame = frame;
    _lastReceived = received;
    _live = true;
    ++_acceptedPackets;
    final mapping = _mapper.update(frame);
    _mapping = mapping;
    _history.add(mapping.normalizedLevel);
    if (_history.length > 80) _history.removeAt(0);
    if (home.isRunning) {
      if (home.mode == PlayMode.song) {
        _hitSongTarget();
      } else if (mapping.trigger && home.mode != PlayMode.rhythm) {
        unawaited(_play(mapping.midiNote, mapping.velocity));
      }
    }
    if (received - _lastPaint >= const Duration(milliseconds: 100) ||
        _acceptedPackets == 1) {
      _lastPaint = received;
      _changed();
    }
  }

  void _streamFailed(String message) {
    if (_disposed) return;
    pause();
    _resetStream();
    _message = message;
    unawaited(transport.disconnect().catchError((Object _) {}));
    _changed();
  }

  Future<void> toggleSession() {
    if (_disposed) return Future<void>.value();
    if (home.isRunning || _starting) {
      pause();
      return Future<void>.value();
    }
    return _startSession();
  }

  Future<void> _startSession() {
    if (_starting) return _pendingStart!;
    final generation = ++_startGeneration;
    _starting = true;
    _message = null;
    _changed();
    return _pendingStart = _initializeSession(generation);
  }

  Future<void> _initializeSession(int generation) async {
    try {
      await audio.initialize();
      if (_disposed || generation != _startGeneration) return;
      if (home.mode == PlayMode.song) {
        final song = songSession;
        if (song == null || !await song.start(home.volume / 100 * 0.7)) {
          if (generation == _startGeneration) {
            _message =
                song?.message ??
                'Could not start song audio. Tap Play to retry.';
          }
          return;
        }
        if (_disposed || generation != _startGeneration) return;
      }
      home.toggleSession();
    } catch (_) {
      if (!_disposed && generation == _startGeneration) {
        _message =
            'Could not start audio. Check sound output and tap Play to retry.';
      }
    } finally {
      if (!_disposed && generation == _startGeneration) {
        _starting = false;
        _pendingStart = null;
        _changed();
      }
    }
  }

  void pause() {
    if (_disposed) return;
    ++_startGeneration;
    ++_padGeneration;
    _starting = false;
    home.pauseSession();
    songSession?.pause();
    _stopVoice();
    _beatTimer?.cancel();
    _changed();
  }

  void reset() {
    if (_disposed) return;
    pause();
    home.resetSession();
    _guidedIndex = 0;
    _beat = 0;
    _mapper.reset();
    _mapping = null;
    songSession?.reset();
    _changed();
  }

  /// Called on inactive/background/route disposal; returning never auto-resumes.
  void suspend() {
    if (_disposed) return;
    pause();
    _resetStream();
    unawaited(transport.disconnect().catchError((Object _) {}));
  }

  void _homeChanged() {
    if (_disposed) return;
    final running = home.isRunning;
    final settings = _readSettings();
    final changed = settings != _settings;
    final modeChanged = settings.$2 != _settings.$2;
    final runningChanged = running != _wasRunning;
    final volumeChanged = settings.$3 != _settings.$3;
    _wasRunning = running;
    _settings = settings;
    if (runningChanged && !running && songSession?.running == true) {
      songSession!.pause();
    }
    if (volumeChanged) songSession?.setVolume(home.volume / 100 * 0.7);
    if (modeChanged) {
      _guidedIndex = 0;
      ++_startGeneration;
      _starting = false;
      songSession?.pause();
      if (running) {
        home.pauseSession();
        return;
      }
    }
    if (changed || runningChanged) {
      _mapper.reset();
      _mapping = null;
      _stopVoice();
      _beatTimer?.cancel();
      if (running && home.mode == PlayMode.rhythm) {
        final interval = Duration(
          microseconds: (60000000 / home.tempo).round(),
        );
        _beatTimer = Timer.periodic(interval, (_) {
          if (_disposed || !home.isRunning) return;
          ++_beat;
          final mapping = _mapping;
          final received = _lastReceived;
          final fresh =
              received != null &&
              _now() - received <= const Duration(milliseconds: 250);
          if (_live && fresh && mapping != null && mapping.isMoving) {
            unawaited(_play(mapping.midiNote, mapping.velocity));
          }
          _changed();
        });
      }
      if (changed) ++_padGeneration;
    }
    _changed();
  }

  Future<void> playPad(int midiNote) async {
    if (_disposed || !MotionMapper.scale.contains(midiNote)) return;
    if (home.mode == PlayMode.song) {
      await playSongNote();
      return;
    }
    final request = ++_padGeneration;
    if (!home.isRunning) await _startSession();
    if (_disposed || !home.isRunning || request != _padGeneration) return;
    await _play(midiNote, 0.85);
  }

  Future<void> _play(int midiNote, double velocity) async {
    if (_disposed || !home.isRunning) return;
    if (home.mode == PlayMode.guided && midiNote != targetMidi) return;
    final generation = ++_voiceGeneration;
    final sessionId = home.playbackSessionId;
    _voiceTimer?.cancel();
    final oldVoice = _activeVoice;
    _activeVoice = null;
    if (oldVoice != null) {
      home.noteStopped(sessionId: sessionId, voiceId: oldVoice);
    }
    try {
      await audio.play(
        midiNote: midiNote,
        instrument: home.instrument,
        volume: (home.volume / 100 * velocity).clamp(0.0, 1.0),
      );
      if (_disposed ||
          generation != _voiceGeneration ||
          !home.isRunning ||
          sessionId != home.playbackSessionId) {
        return;
      }
      _activeVoice = generation;
      home.noteStarted(
        note: MusicNote(midiNote),
        sessionId: sessionId,
        voiceId: generation,
      );
      if (home.mode == PlayMode.guided) ++_guidedIndex;
      // Let the full 600 ms recorded envelope finish, including after a
      // movement ends. Pause/disconnect and newer notes still stop immediately.
      _voiceTimer = Timer(const Duration(milliseconds: 600), () {
        if (!_disposed && generation == _voiceGeneration) _stopVoice();
      });
      _changed();
    } catch (_) {
      if (!_disposed && generation == _voiceGeneration) {
        pause();
        _message = 'Could not play sound. Check your audio output and tap Play to retry.';
        _changed();
      }
    }
  }

  void _stopVoice() {
    ++_voiceGeneration;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    final voice = _activeVoice;
    _activeVoice = null;
    if (voice != null) {
      home.noteStopped(sessionId: home.playbackSessionId, voiceId: voice);
    }
    unawaited(audio.stop().catchError((Object _) {}));
  }

  @override
  void dispose() {
    if (_disposed) return;
    home.removeListener(_homeChanged);
    songSession?.removeListener(_songChanged);
    home.pauseSession();
    _disposed = true;
    ++_startGeneration;
    ++_voiceGeneration;
    _watchdog?.cancel();
    _voiceTimer?.cancel();
    _beatTimer?.cancel();
    unawaited(_connectionSubscription.cancel());
    unawaited(_packetSubscription.cancel());
    unawaited(_interruptionSubscription.cancel());
    unawaited(transport.dispose().catchError((Object _) {}));
    unawaited(audio.dispose().catchError((Object _) {}));
    songSession?.dispose();
    super.dispose();
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
