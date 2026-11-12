import 'dart:math' as math;

import 'motion_frame.dart';

/// Demo movement mapping; these settings are not clinical calibration limits.
final class MotionMapping {
  const MotionMapping({
    required this.normalizedLevel,
    required this.midiNote,
    required this.velocity,
    required this.isMoving,
    required this.trigger,
    required this.tiltDegrees,
  });

  final double normalizedLevel;
  final int midiNote;
  final double velocity;
  final bool isMoving;

  /// A new note may be played on this sample. No audio occurs in this mapper.
  final bool trigger;
  final double tiltDegrees;
}

/// X-axis gravity tilt chooses C4-C5; angular speed gates note triggering.
///
/// Feed only accepted ordered frames. Call [reset] at each session/stream change.
/// The coordinator must independently stop notes after a bounded duration and
/// stop audio when the stream stalls; no mapper callback can detect absent data.
final class MotionMapper {
  MotionMapper({
    this.tiltRangeDegrees = 60,
    this.onThresholdDps = 25,
    this.offThresholdDps = 12,
    this.retriggerInterval = const Duration(milliseconds: 350),
    this.filterTimeConstant = const Duration(milliseconds: 120),
    this.pitchHysteresis = 0.02,
  }) {
    if (!tiltRangeDegrees.isFinite ||
        tiltRangeDegrees <= 0 ||
        tiltRangeDegrees > 90 ||
        !onThresholdDps.isFinite ||
        !offThresholdDps.isFinite ||
        onThresholdDps <= offThresholdDps ||
        offThresholdDps < 0 ||
        retriggerInterval <= Duration.zero ||
        filterTimeConstant < Duration.zero ||
        !pitchHysteresis.isFinite ||
        pitchHysteresis < 0 ||
        pitchHysteresis >= 0.0625) {
      throw ArgumentError('Invalid demo motion mapping configuration.');
    }
  }

  static const scale = [60, 62, 64, 65, 67, 69, 71, 72];
  final double tiltRangeDegrees;
  final double onThresholdDps;
  final double offThresholdDps;
  final Duration retriggerInterval;
  final Duration filterTimeConstant;
  final double pitchHysteresis;

  MotionVector? _gravity;
  int? _lastTimestampUs;
  int? _lastTriggerUs;
  int? _pitchIndex;
  bool _moving = false;

  void reset() {
    _gravity = null;
    _lastTimestampUs = null;
    _lastTriggerUs = null;
    _pitchIndex = null;
    _moving = false;
  }

  MotionMapping update(MotionFrame frame) {
    final previousTimestamp = _lastTimestampUs;
    final deltaUs = previousTimestamp == null
        ? 0
        : (frame.timestampUs - previousTimestamp) & 0xffffffff;
    final valid = frame.accelerationG.isFinite && frame.gyroDps.isFinite;
    final ordered =
        previousTimestamp == null || (deltaUs > 0 && deltaUs < 0x80000000);
    if (!valid || !ordered) {
      return _result(trigger: false, speedDps: 0, moving: false);
    }
    _lastTimestampUs = frame.timestampUs;

    // Translation/impact corrupts gravity-based tilt. Retain the last estimate
    // outside this broad diagnostic band instead of inventing an orientation.
    final magnitude = frame.accelerationG.magnitude;
    if (magnitude >= 0.5 && magnitude <= 1.5) {
      final old = _gravity;
      if (old == null || filterTimeConstant == Duration.zero) {
        _gravity = frame.accelerationG;
      } else {
        final alpha =
            1 - math.exp(-deltaUs / filterTimeConstant.inMicroseconds);
        _gravity = MotionVector(
          old.x + alpha * (frame.accelerationG.x - old.x),
          old.y + alpha * (frame.accelerationG.y - old.y),
          old.z + alpha * (frame.accelerationG.z - old.z),
        );
      }
    }

    final speed = frame.gyroDps.magnitude;
    _moving =
        _gravity != null &&
        (_moving ? speed > offThresholdDps : speed >= onThresholdDps);
    final lastTriggerUs = _lastTriggerUs;
    final canRetrigger =
        lastTriggerUs == null ||
        ((frame.timestampUs - lastTriggerUs) & 0xffffffff) >=
            retriggerInterval.inMicroseconds;
    final trigger = _moving && canRetrigger;
    if (trigger) _lastTriggerUs = frame.timestampUs;
    return _result(trigger: trigger, speedDps: speed, moving: _moving);
  }

  MotionMapping _result({
    required bool trigger,
    required double speedDps,
    required bool moving,
  }) {
    final gravity = _gravity;
    final tilt = gravity == null
        ? 0.0
        : math.atan2(
                gravity.x,
                math.sqrt(gravity.y * gravity.y + gravity.z * gravity.z),
              ) *
              180 /
              math.pi;
    final level = ((tilt + tiltRangeDegrees) / (2 * tiltRangeDegrees)).clamp(
      0.0,
      1.0,
    );
    final candidate = (level * scale.length).floor().clamp(0, scale.length - 1);
    final old = _pitchIndex;
    if (old == null ||
        (candidate > old &&
            level > (old + 1) / scale.length + pitchHysteresis) ||
        (candidate < old && level < old / scale.length - pitchHysteresis)) {
      _pitchIndex = candidate;
    }
    return MotionMapping(
      normalizedLevel: level,
      midiNote: scale[_pitchIndex ?? candidate],
      velocity: (0.35 + 0.65 * speedDps / 180).clamp(0.0, 1.0),
      isMoving: moving,
      trigger: trigger,
      tiltDegrees: tilt,
    );
  }
}
