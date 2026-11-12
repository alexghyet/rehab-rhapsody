import 'dart:typed_data';

import 'motion_frame.dart';

/// Matches firmware/ble_motion/ble_motion.ino. Ranges are fixed in v1.
abstract final class MotionPacketDecoder {
  static const serviceUuid = 'b8141000-8c3f-4b0b-9a7c-1a16adcc7a21';
  static const characteristicUuid = 'b8141001-8c3f-4b0b-9a7c-1a16adcc7a21';
  static const packetLength = 20;
  static const accelerationGPerCount = 0.000122;
  static const gyroDpsPerCount = 0.0175;

  static MotionFrame decode(List<int> bytes) {
    if (bytes.length != packetLength) {
      throw const FormatException('Motion v1 requires exactly 20 bytes.');
    }
    if (bytes.any((value) => value < 0 || value > 255)) {
      throw const FormatException('Motion packet values must be bytes.');
    }
    if (bytes[0] != 1 || bytes[1] != 0) {
      throw const FormatException(
        'Unsupported motion version or reserved bits.',
      );
    }

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    MotionVector vectorAt(int offset, double scale) => MotionVector(
      data.getInt16(offset, Endian.little) * scale,
      data.getInt16(offset + 2, Endian.little) * scale,
      data.getInt16(offset + 4, Endian.little) * scale,
    );

    return MotionFrame(
      sequence: data.getUint16(2, Endian.little),
      timestampUs: data.getUint32(4, Endian.little),
      accelerationG: vectorAt(8, accelerationGPerCount),
      gyroDps: vectorAt(14, gyroDpsPerCount),
    );
  }
}
