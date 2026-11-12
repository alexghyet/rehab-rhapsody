import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/motion/motion.dart';

void main() {
  test(
    'duplicates and out-of-order frames cannot replace the accepted cursor',
    () {
      final guard = MotionStreamGuard();
      expect(guard.accept(_frame(100, 100000), Duration.zero), isTrue);
      expect(guard.accept(_frame(100, 100000), _ms(20)), isFalse);
      expect(guard.accept(_frame(99, 80000), _ms(30)), isFalse);
      expect(guard.accept(_frame(101, 100000), _ms(40)), isFalse);
      expect(guard.accept(_frame(101, 90000), _ms(50)), isFalse);
      expect(guard.accept(_frame(103, 160000), _ms(60)), isTrue);
      expect(guard.lastSequenceDelta, 3);
    },
  );

  test(
    'sequence and timestamp wrap are accepted, reverse wrap is rejected',
    () {
      final guard = MotionStreamGuard();
      expect(guard.accept(_frame(65535, 4294967200), Duration.zero), isTrue);
      expect(guard.accept(_frame(0, 50000), _ms(51)), isTrue);
      expect(guard.lastSequenceDelta, 1);
      expect(guard.accept(_frame(65535, 4294967200), _ms(60)), isFalse);
      expect(guard.accept(_frame(1, 70000), _ms(71)), isTrue);
    },
  );

  test(
    'receiver clock cannot move backwards and ambiguous jumps are rejected',
    () {
      final guard = MotionStreamGuard();
      expect(guard.accept(_frame(1, 100000), _ms(100)), isTrue);
      expect(guard.accept(_frame(2, 120000), _ms(90)), isFalse);
      expect(guard.accept(_frame(32769, 120000), _ms(120)), isFalse);
      expect(guard.accept(_frame(2, 120000), _ms(120)), isTrue);
    },
  );

  test('duplicates do not keep an expired stream alive; explicit reset required', () {
    final guard = MotionStreamGuard();
    expect(guard.accept(_frame(1, 100000), Duration.zero), isTrue);
    expect(guard.accept(_frame(1, 100000), _ms(1500)), isFalse);
    expect(guard.accept(_frame(2, 120000), _ms(2100)), isFalse);
    expect(guard.isExpired, isTrue);
    expect(guard.accept(_frame(3, 140000), _ms(2200)), isFalse);
    guard.reset();
    expect(guard.isExpired, isFalse);
    // New subscription can begin at arbitrary counters, including after reboot.
    expect(guard.accept(_frame(0, 1000), _ms(2200)), isTrue);
  });

  test(
    'a long device-clock gap expires even if delivery happens in a burst',
    () {
      final guard = MotionStreamGuard();
      expect(guard.accept(_frame(1, 100000), Duration.zero), isTrue);
      expect(guard.accept(_frame(2, 3100000), _ms(20)), isFalse);
      expect(guard.isExpired, isTrue);
    },
  );

  test('invalid counter domains and non-finite samples are rejected', () {
    final guard = MotionStreamGuard();
    expect(guard.accept(_frame(-1, 100), Duration.zero), isFalse);
    expect(guard.accept(_frame(65536, 100), Duration.zero), isFalse);
    expect(guard.accept(_frame(1, -1), Duration.zero), isFalse);
    expect(guard.accept(_frame(1, 4294967296), Duration.zero), isFalse);
    expect(guard.accept(_frame(1, 100), _ms(-1)), isFalse);
    expect(
      guard.accept(
        const MotionFrame(
          sequence: 1,
          timestampUs: 100,
          accelerationG: MotionVector(double.nan, 0, 1),
          gyroDps: MotionVector(0, 0, 0),
        ),
        Duration.zero,
      ),
      isFalse,
    );
    expect(guard.accept(_frame(1, 100), Duration.zero), isTrue);
  });
}

MotionFrame _frame(int sequence, int timestampUs) => MotionFrame(
  sequence: sequence,
  timestampUs: timestampUs,
  accelerationG: const MotionVector(0, 0, 1),
  gyroDps: const MotionVector(0, 0, 0),
);

Duration _ms(int value) => Duration(milliseconds: value);
