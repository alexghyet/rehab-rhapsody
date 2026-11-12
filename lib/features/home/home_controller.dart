import 'dart:async';

import 'package:flutter/foundation.dart';

import '../music/music_note.dart';
import 'home_options.dart';

/// Session/setup state and confirmed playback feedback from an audio adapter.
class HomeController extends ChangeNotifier {
  Instrument _instrument = Instrument.piano;
  PlayMode _mode = PlayMode.free;
  double _volume = 65;
  double _tempo = 90;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _hasStarted = false;
  int _playbackSessionId = 0;
  final Map<int, MusicNote> _activeNotes = {};

  Instrument get instrument => _instrument;
  PlayMode get mode => _mode;
  double get volume => _volume;
  double get tempo => _tempo;
  Duration get elapsed => _elapsed;
  bool get isRunning => _timer != null;
  bool get canReset => _hasStarted && !isRunning;

  /// Capture this ID when scheduling audio, then return it with its callbacks.
  /// Each start/resume gets a new ID so delayed events cannot revive old notes.
  int get playbackSessionId => _playbackSessionId;

  /// For overlapping voices, display the most recently started active note.
  MusicNote? get currentNote =>
      _activeNotes.isEmpty ? null : _activeNotes.values.last;

  String get formattedTime {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(_elapsed.inHours)}:'
        '${two(_elapsed.inMinutes.remainder(60))}:'
        '${two(_elapsed.inSeconds.remainder(60))}';
  }

  void toggleSession() {
    if (isRunning) {
      pauseSession();
      return;
    }
    _hasStarted = true;
    _playbackSessionId++;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseSession() {
    if (!isRunning) return;
    _timer!.cancel();
    _timer = null;
    _activeNotes.clear();
    notifyListeners();
  }

  /// Reset a paused session without changing instrument, mode, or sliders.
  void resetSession() {
    if (!canReset) return;
    _elapsed = Duration.zero;
    _hasStarted = false;
    _activeNotes.clear();
    notifyListeners();
  }

  /// Report a pitched voice only after the audio adapter starts playback.
  /// [voiceId] must be unique per note trigger within [sessionId], including
  /// repeated pitches. Motion readings alone should never call this method.
  void noteStarted({
    required MusicNote note,
    required int sessionId,
    required int voiceId,
  }) {
    if (!isRunning || sessionId != _playbackSessionId) return;
    if (_activeNotes.containsKey(voiceId)) return;
    _activeNotes[voiceId] = note;
    notifyListeners();
  }

  /// End exactly one voice; an older note-off cannot clear a newer voice.
  void noteStopped({required int sessionId, required int voiceId}) {
    if (!isRunning || sessionId != _playbackSessionId) return;
    if (_activeNotes.remove(voiceId) == null) return;
    notifyListeners();
  }

  void selectInstrument(Instrument value) {
    if (_instrument == value) return;
    _instrument = value;
    notifyListeners();
  }

  void selectMode(PlayMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void setVolume(double value) {
    if (!value.isFinite) return;
    final next = value.clamp(0.0, 100.0);
    if (_volume == next) return;
    _volume = next;
    notifyListeners();
  }

  void setTempo(double value) {
    if (!value.isFinite) return;
    final next = value.clamp(40.0, 140.0);
    if (_tempo == next) return;
    _tempo = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _activeNotes.clear();
    super.dispose();
  }
}
