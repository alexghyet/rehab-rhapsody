import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/audio/demo_audio_engine.dart';
import 'package:rehab_rhapsody/features/home/home_options.dart';

void main() {
  test('every selectable timbre and pitch has a bounded, faded PCM WAV', () {
    for (final instrument in Instrument.values) {
      for (final midiNote in demoMidiNotes) {
        final path = 'assets/${demoAudioAsset(instrument, midiNote)}';
        final bytes = File(path).readAsBytesSync();
        final data = ByteData.sublistView(bytes);
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF', reason: path);
        expect(
          String.fromCharCodes(bytes.sublist(8, 12)),
          'WAVE',
          reason: path,
        );
        expect(data.getUint16(20, Endian.little), 1, reason: path); // PCM.
        expect(data.getUint16(22, Endian.little), 1, reason: path); // Mono.
        expect(data.getUint32(24, Endian.little), 44100, reason: path);
        expect(data.getUint16(34, Endian.little), 16, reason: path);
        expect(data.getUint32(40, Endian.little), 52920, reason: path);
        expect(bytes.length, 52964, reason: path);
        expect(data.getInt16(44, Endian.little), 0, reason: path);
        expect(data.getInt16(bytes.length - 2, Endian.little), 0, reason: path);
        var peak = 0;
        for (var offset = 44; offset < bytes.length; offset += 2) {
          peak = math.max(peak, data.getInt16(offset, Endian.little).abs());
        }
        expect(peak, inInclusiveRange(20000, 23600), reason: path);
      }
    }
  });
}
