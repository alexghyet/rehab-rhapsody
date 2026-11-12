import 'dart:math' as math;

/// Three axes in the units named by the field containing this vector.
final class MotionVector {
  const MotionVector(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  MotionVector scaled(double factor) =>
      MotionVector(x * factor, y * factor, z * factor);
}

/// A validated v1 baton sample. Device counters wrap and are not wall time.
final class MotionFrame {
  const MotionFrame({
    required this.sequence,
    required this.timestampUs,
    required this.accelerationG,
    required this.gyroDps,
  });

  final int sequence;
  final int timestampUs;
  final MotionVector accelerationG;
  final MotionVector gyroDps;

  MotionVector get accelerationMps2 => accelerationG.scaled(9.80665);
  MotionVector get angularVelocityRadPerSec => gyroDps.scaled(math.pi / 180);
}
