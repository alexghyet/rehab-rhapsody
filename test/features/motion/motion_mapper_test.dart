import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/motion/motion.dart';

void main() {
  test(
    'captured resting-like bias stays silent and has a finite chart level',
    () {
      final result = MotionMapper().update(
        const MotionFrame(
          sequence: 911,
          timestampUs: 106504882,
          accelerationG: MotionVector(-0.005124, 0.130418, 1.034926),
          gyroDps: MotionVector(2.135, -4.34, 0.14),
        ),
      );
      expect(result.isMoving, isFalse);
      expect(result.trigger, isFalse);
      expect(result.normalizedLevel, closeTo(0.497655, 0.00001));
    },
  );

  test('gyro hysteresis and minimum retrigger interval prevent chatter', () {
    final mapper = MotionMapper(filterTimeConstant: Duration.zero);
    expect(mapper.update(_frame(0, speed: 24)).trigger, isFalse);
    final onset = mapper.update(_frame(20000, speed: 25));
    expect(onset.isMoving, isTrue);
    expect(onset.trigger, isTrue);
    final middle = mapper.update(_frame(40000, speed: 18));
    expect(middle.isMoving, isTrue);
    expect(middle.trigger, isFalse);
    expect(mapper.update(_frame(60000, speed: 12)).isMoving, isFalse);
    // Re-entering movement does not bypass the retrigger limit.
    expect(mapper.update(_frame(80000, speed: 30)).trigger, isFalse);
    expect(mapper.update(_frame(370000, speed: 30)).trigger, isTrue);
    expect(mapper.update(_frame(390000, speed: 30)).trigger, isFalse);
    expect(mapper.update(_frame(720000, speed: 30)).trigger, isTrue);
  });

  test('gravity tilt covers exactly the eight C-major pitches', () {
    final mapper = MotionMapper(filterTimeConstant: Duration.zero);
    const tilts = [-75.0, -37.5, -22.5, -7.5, 7.5, 22.5, 37.5, 75.0];
    for (var i = 0; i < tilts.length; i++) {
      mapper.reset();
      final result = mapper.update(_frame(0, tilt: tilts[i], speed: 50));
      expect(result.midiNote, MotionMapper.scale[i]);
      expect(result.normalizedLevel, inInclusiveRange(0, 1));
      expect(result.velocity, inInclusiveRange(0, 1));
    }
  });

  test('pitch boundary hysteresis holds a pitch through tiny tilt noise', () {
    final mapper = MotionMapper(filterTimeConstant: Duration.zero);
    final first = mapper.update(_frame(0, tilt: -1, speed: 40));
    expect(first.midiNote, 65);
    expect(mapper.update(_frame(20000, tilt: 1, speed: 40)).midiNote, 65);
    expect(mapper.update(_frame(40000, tilt: 4, speed: 40)).midiNote, 67);
    expect(mapper.update(_frame(60000, tilt: -1, speed: 40)).midiNote, 67);
    expect(mapper.update(_frame(80000, tilt: -4, speed: 40)).midiNote, 65);
  });

  test(
    'filter timing and retrigger timing work across device timestamp wrap',
    () {
      final mapper = MotionMapper();
      expect(
        mapper.update(_frame(4294900000, tilt: -40, speed: 30)).trigger,
        isTrue,
      );
      final afterWrap = mapper.update(_frame(100000, tilt: 40, speed: 30));
      expect(afterWrap.tiltDegrees, greaterThan(-40));
      expect(afterWrap.tiltDegrees, lessThan(40));
      expect(afterWrap.trigger, isFalse);
      expect(
        mapper.update(_frame(300000, tilt: 40, speed: 30)).trigger,
        isTrue,
      );
    },
  );

  test('reset clears movement, pitch filtering, and retrigger history', () {
    final mapper = MotionMapper();
    expect(mapper.update(_frame(1000, tilt: -50, speed: 50)).trigger, isTrue);
    mapper.reset();
    final result = mapper.update(_frame(1, tilt: 50, speed: 50));
    expect(result.trigger, isTrue);
    expect(result.midiNote, 72);
  });

  test(
    'unusable gravity and malformed values cannot invent a first gesture',
    () {
      final mapper = MotionMapper();
      final freeFall = mapper.update(
        const MotionFrame(
          sequence: 1,
          timestampUs: 1,
          accelerationG: MotionVector(0, 0, 0),
          gyroDps: MotionVector(100, 0, 0),
        ),
      );
      expect(freeFall.trigger, isFalse);
      expect(freeFall.isMoving, isFalse);
      final invalid = mapper.update(
        const MotionFrame(
          sequence: 2,
          timestampUs: 2,
          accelerationG: MotionVector(double.nan, 0, 1),
          gyroDps: MotionVector(100, 0, 0),
        ),
      );
      expect(invalid.trigger, isFalse);
      expect(invalid.normalizedLevel.isFinite, isTrue);
    },
  );
}

MotionFrame _frame(int timestampUs, {double tilt = 0, double speed = 0}) {
  final radians = tilt * math.pi / 180;
  return MotionFrame(
    sequence: (timestampUs ~/ 20000) & 0xffff,
    timestampUs: timestampUs,
    accelerationG: MotionVector(math.sin(radians), 0, math.cos(radians)),
    gyroDps: MotionVector(speed, 0, 0),
  );
}
