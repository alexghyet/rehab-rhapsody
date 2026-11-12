import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/music/music_note.dart';

void main() {
  test('standard MIDI notes retain all natural pitches and sharps', () {
    const labels = [
      'C4',
      'C♯4',
      'D4',
      'D♯4',
      'E4',
      'F4',
      'F♯4',
      'G4',
      'G♯4',
      'A4',
      'A♯4',
      'B4',
    ];
    for (var pitchClass = 0; pitchClass < labels.length; pitchClass++) {
      final note = MusicNote(60 + pitchClass);
      expect(note.midiNote, 60 + pitchClass);
      expect(note.pitchClass, pitchClass);
      expect(note.label, labels[pitchClass]);
      expect(note.letter, labels[pitchClass][0]);
      expect(note.isSharp, labels[pitchClass].contains('♯'));
      expect(note.octave, 4);
    }
  });

  test('octaves change at C and cover the MIDI boundaries', () {
    expect(MusicNote(0).label, 'C-1');
    expect(MusicNote(11).label, 'B-1');
    expect(MusicNote(12).label, 'C0');
    expect(MusicNote(59).label, 'B3');
    expect(MusicNote(60).label, 'C4');
    expect(MusicNote(69).label, 'A4');
    expect(MusicNote(72).label, 'C5');
    expect(MusicNote(127).label, 'G9');
  });

  test(
    'display labels use subscript octaves and spoken labels name sharps',
    () {
      expect(MusicNote(60).displayLabel, 'C₄');
      expect(MusicNote(61).displayLabel, 'C♯₄');
      expect(MusicNote(0).displayLabel, 'C₋₁');
      expect(MusicNote(127).displayLabel, 'G₉');
      expect(MusicNote(60).spokenLabel, 'C, octave 4');
      expect(MusicNote(61).spokenLabel, 'C sharp, octave 4');
      expect(MusicNote(0).spokenLabel, 'C, octave -1');
    },
  );

  test('invalid MIDI values are rejected at runtime', () {
    expect(() => MusicNote(-1), throwsRangeError);
    expect(() => MusicNote(128), throwsRangeError);
  });

  test('notes have value equality by MIDI number', () {
    expect(MusicNote(60), MusicNote(60));
    expect(MusicNote(60).hashCode, MusicNote(60).hashCode);
    expect(MusicNote(60), isNot(MusicNote(72)));
    expect({MusicNote(60), MusicNote(60), MusicNote(61)}, hasLength(2));
  });
}
