/// One playable onset on a song's backing-track timeline.
class SongNote {
  const SongNote({
    required this.id,
    required this.midiNote,
    required this.lane,
    required this.at,
    required this.duration,
  });

  final int id;
  final int midiNote;
  final int lane;
  final Duration at;
  final Duration duration;
}

/// A bundled arrangement. [notes] includes the count-in offset already.
class SongDefinition {
  const SongDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.composer,
    required this.bpm,
    this.beatsPerBar = 4,
    this.countInBeats = 4,
    required this.notes,
    required this.duration,
    required this.backingAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final String composer;
  final int bpm;
  final int beatsPerBar;
  final int countInBeats;
  final List<SongNote> notes;
  final Duration duration;

  /// Relative to Flutter's assets directory, as expected by AssetSource.
  final String backingAsset;

  Duration get beatDuration =>
      Duration(microseconds: (Duration.microsecondsPerMinute / bpm).round());

  Duration get countInDuration => Duration(
    microseconds: (Duration.microsecondsPerMinute * countInBeats / bpm).round(),
  );
}
