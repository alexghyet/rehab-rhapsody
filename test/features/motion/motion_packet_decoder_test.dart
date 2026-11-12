import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/motion/motion.dart';

void main() {
  test(
    'all five captured LightBlue frames decode with the documented units',
    () {
      final fixture = jsonDecode(
        File('firmware/captures/lightblue-motion-v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final samples = fixture['samples'] as List<dynamic>;
      expect(samples, hasLength(5));
      for (final sample in samples.cast<Map<String, dynamic>>()) {
        final frame = MotionPacketDecoder.decode(_hex(sample['hex'] as String));
        expect(frame.sequence, sample['sequence']);
        expect(frame.timestampUs, sample['timestampUs']);
        final accel = (sample['accelerationRaw'] as List<dynamic>).cast<int>();
        final gyro = (sample['angularVelocityRaw'] as List<dynamic>)
            .cast<int>();
        _expectVector(frame.accelerationG, accel.map((v) => v * 0.000122));
        _expectVector(frame.gyroDps, gyro.map((v) => v * 0.0175));
      }

      final latest = MotionPacketDecoder.decode(
        _hex('01008F03B2225906D6FF2D0423217A0008FF0800'),
      );
      _expectVector(latest.accelerationG, [-0.005124, 0.130418, 1.034926]);
      _expectVector(latest.gyroDps, [2.135, -4.34, 0.14]);
      expect(latest.accelerationG.magnitude, closeTo(1.043123643, 1e-8));
      expect(latest.accelerationMps2.z, closeTo(1.034926 * 9.80665, 1e-10));
      expect(latest.angularVelocityRadPerSec.x, closeTo(0.03726277953, 1e-10));
    },
  );

  test(
    'signed sensor bounds and unsigned counter bounds retain little endian',
    () {
      final frame = MotionPacketDecoder.decode(
        _hex('0100FFFFFEFFFFFF0080FF7F01000000FFFF0080'),
      );
      expect(frame.sequence, 65535);
      expect(frame.timestampUs, 4294967294);
      _expectVector(frame.accelerationG, [-3.997696, 3.997574, 0.000122]);
      _expectVector(frame.gyroDps, [0, -0.0175, -573.44]);
    },
  );

  test(
    'malformed lengths, unknown protocol and invalid bytes are rejected',
    () {
      final packet = _hex('01008F03B2225906D6FF2D0423217A0008FF0800');
      for (final invalid in [
        <int>[],
        packet.sublist(1),
        [...packet, 0],
        [...packet]..[0] = 2,
        [...packet]..[1] = 1,
        [...packet]..[8] = -1,
        [...packet]..[8] = 256,
      ]) {
        expect(
          () => MotionPacketDecoder.decode(invalid),
          throwsFormatException,
        );
      }
    },
  );
}

List<int> _hex(String text) => [
  for (var i = 0; i < text.length; i += 2)
    int.parse(text.substring(i, i + 2), radix: 16),
];

void _expectVector(MotionVector vector, Iterable<num> expected) {
  final values = expected.toList();
  expect(vector.x, closeTo(values[0], 1e-10));
  expect(vector.y, closeTo(values[1], 1e-10));
  expect(vector.z, closeTo(values[2], 1e-10));
}
