/// A note using standard MIDI numbering (middle C is 60, or C4).
final class MusicNote {
  MusicNote(int midiNote)
    : midiNote = RangeError.checkValueInInterval(midiNote, 0, 127, 'midiNote');

  final int midiNote;

  static const _letters = [
    'C',
    'C',
    'D',
    'D',
    'E',
    'F',
    'F',
    'G',
    'G',
    'A',
    'A',
    'B',
  ];
  static const _subscripts = {
    '-': '₋',
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
  };

  int get pitchClass => midiNote % 12;
  String get letter => _letters[pitchClass];
  bool get isSharp => switch (pitchClass) {
    1 || 3 || 6 || 8 || 10 => true,
    _ => false,
  };
  int get octave => midiNote ~/ 12 - 1;

  /// The conventional note name, for example C4 or F♯4.
  String get label => '$letter${isSharp ? '♯' : ''}$octave';

  /// The note name with a subscript octave for the current-note display.
  String get displayLabel {
    final subscript = octave
        .toString()
        .split('')
        .map((c) => _subscripts[c]!)
        .join();
    return '$letter${isSharp ? '♯' : ''}$subscript';
  }

  String get spokenLabel => '$letter${isSharp ? ' sharp' : ''}, octave $octave';

  @override
  bool operator ==(Object other) =>
      other is MusicNote && other.midiNote == midiNote;

  @override
  int get hashCode => midiNote.hashCode;

  @override
  String toString() => label;
}
