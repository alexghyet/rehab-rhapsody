import 'motion_frame.dart';

/// Orders one notification subscription using a monotonic receiver clock.
///
/// Call [reset] whenever the connection/subscription generation changes. A long
/// silence expires this guard; it never implicitly trusts a delayed old packet.
final class MotionStreamGuard {
  MotionStreamGuard({this.maxSilence = const Duration(seconds: 2)}) {
    if (maxSilence <= Duration.zero ||
        maxSilence.inMicroseconds >= 0x80000000) {
      throw ArgumentError.value(maxSilence, 'maxSilence');
    }
  }

  final Duration maxSilence;
  MotionFrame? _last;
  Duration? _lastReceivedAt;
  bool _isExpired = false;
  int _lastSequenceDelta = 0;

  bool get isExpired => _isExpired;
  int get lastSequenceDelta => _lastSequenceDelta;

  void reset() {
    _last = null;
    _lastReceivedAt = null;
    _isExpired = false;
    _lastSequenceDelta = 0;
  }

  /// Returns false for duplicates, stale frames, reversed clocks, or expiry.
  bool accept(MotionFrame frame, Duration receivedAt) {
    if (_isExpired ||
        frame.sequence < 0 ||
        frame.sequence > 0xffff ||
        frame.timestampUs < 0 ||
        frame.timestampUs > 0xffffffff ||
        !frame.accelerationG.isFinite ||
        !frame.gyroDps.isFinite ||
        receivedAt < Duration.zero) {
      return false;
    }

    final last = _last;
    final lastReceivedAt = _lastReceivedAt;
    var sequenceDelta = 0;
    if (last != null && lastReceivedAt != null) {
      final receiverDelta = receivedAt - lastReceivedAt;
      if (receiverDelta < Duration.zero) return false;
      if (receiverDelta > maxSilence) {
        _isExpired = true;
        return false;
      }
      sequenceDelta = (frame.sequence - last.sequence) & 0xffff;
      if (sequenceDelta == 0 || sequenceDelta >= 0x8000) return false;
      final deviceDelta = (frame.timestampUs - last.timestampUs) & 0xffffffff;
      if (deviceDelta == 0 || deviceDelta >= 0x80000000) return false;
      if (deviceDelta > maxSilence.inMicroseconds) {
        _isExpired = true;
        return false;
      }
    }

    _last = frame;
    _lastReceivedAt = receivedAt;
    _lastSequenceDelta = sequenceDelta;
    return true;
  }
}
