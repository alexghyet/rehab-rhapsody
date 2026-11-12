import '../home/home_options.dart';

/// One short, pitched demo voice. Volume is a linear value from 0 to 1.
///
/// A completed [play] command means that playback was accepted by the player,
/// not that a microphone verified the speaker. Callers must also check their
/// session/voice generation after awaiting: superseded commands are skipped.
abstract class DemoAudioEngine {
  Stream<void> get interruptions => const Stream<void>.empty();

  Future<void> initialize();
  Future<void> play({
    required int midiNote,
    required Instrument instrument,
    required double volume,
  });
  Future<void> stop();
  Future<void> dispose();
}

/// Low-level seam for testing cancellation during asynchronous asset loading.
abstract interface class DemoAudioDriver {
  Stream<void> get interruptions;
  Future<void> initialize();
  Future<void> prepare(String assetPath);
  Future<void> setVolume(double volume);
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

const demoMidiNotes = <int>[60, 62, 64, 65, 67, 69, 71, 72];

String demoAudioAsset(Instrument instrument, int midiNote) {
  if (!demoMidiNotes.contains(midiNote)) {
    throw ArgumentError.value(midiNote, 'midiNote', 'Unsupported demo pitch');
  }
  // audioplayers' default asset prefix is "assets/".
  return 'audio/demo/${instrument.name}_$midiNote.wav';
}
