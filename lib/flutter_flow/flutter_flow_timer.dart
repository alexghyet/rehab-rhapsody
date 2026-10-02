import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

export 'package:stop_watch_timer/stop_watch_timer.dart';

class FlutterFlowTimerController {
  FlutterFlowTimerController(this.timer);

  final StopWatchTimer timer;

  bool get isRunning => timer.isRunning;

  void onStartTimer() => timer.onStartTimer();
  void onStopTimer() => timer.onStopTimer();
  void onResetTimer() => timer.onResetTimer();

  Future<void> dispose() => timer.dispose();
}

class FlutterFlowTimer extends StatefulWidget {
  const FlutterFlowTimer({
    super.key,
    required this.initialTime,
    required this.controller,
    required this.getDisplayTime,
    required this.onChanged,
    this.updateStateInterval,
    this.onEnded,
    required this.textAlign,
    required this.style,
  });

  final int initialTime;
  final FlutterFlowTimerController controller;
  final String Function(int) getDisplayTime;
  final Function(int value, String displayTime, bool shouldUpdate) onChanged;
  final Duration? updateStateInterval;
  final Function()? onEnded;
  final TextAlign textAlign;
  final TextStyle style;

  @override
  State<FlutterFlowTimer> createState() => _FlutterFlowTimerState();
}

class _FlutterFlowTimerState extends State<FlutterFlowTimer> {
  StopWatchTimer get timer => widget.controller.timer;

  StreamSubscription<int>? _rawTimeSubscription;
  StreamSubscription<bool>? _endedSubscription;

  late String _displayTime;
  late int _lastUpdateMs;

  @override
  void initState() {
    super.initState();
    timer.setPresetTime(mSec: widget.initialTime, add: false);
    _lastUpdateMs = timer.rawTime.value;
    _displayTime = widget.getDisplayTime(_lastUpdateMs);
    _rawTimeSubscription = timer.rawTime.listen(_onTick);
    _endedSubscription = timer.fetchEnded.listen((ended) {
      if (ended) widget.onEnded?.call();
    });
  }

  void _onTick(int value) {
    final displayTime = widget.getDisplayTime(value);
    final interval = widget.updateStateInterval;
    final shouldUpdate =
        interval != null &&
        (value - _lastUpdateMs).abs() >= interval.inMilliseconds;
    if (shouldUpdate) _lastUpdateMs = value;
    widget.onChanged(value, displayTime, shouldUpdate);
    if (mounted && displayTime != _displayTime) {
      setState(() => _displayTime = displayTime);
    }
  }

  @override
  void dispose() {
    _rawTimeSubscription?.cancel();
    _endedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(_displayTime, textAlign: widget.textAlign, style: widget.style);
}
