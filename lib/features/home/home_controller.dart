import 'dart:async';

import 'package:flutter/foundation.dart';

import 'home_options.dart';

/// Local session and setup state. Hardware and audio can subscribe here later.
class HomeController extends ChangeNotifier {
  Instrument _instrument = Instrument.piano;
  PlayMode _mode = PlayMode.free;
  double _volume = 65;
  double _tempo = 90;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  Instrument get instrument => _instrument;
  PlayMode get mode => _mode;
  double get volume => _volume;
  double get tempo => _tempo;
  Duration get elapsed => _elapsed;
  bool get isRunning => _timer != null;

  String get formattedTime {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(_elapsed.inHours)}:'
        '${two(_elapsed.inMinutes.remainder(60))}:'
        '${two(_elapsed.inSeconds.remainder(60))}';
  }

  String get status {
    if (isRunning) return 'Conducting, keep it flowing';
    return _elapsed > Duration.zero
        ? 'Paused, tap to continue'
        : 'Tap play when you’re ready';
  }

  void toggleSession() {
    if (isRunning) {
      pauseSession();
      return;
    }
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
    super.dispose();
  }
}
