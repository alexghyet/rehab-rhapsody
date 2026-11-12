import 'dart:collection';

import 'song.dart';

enum SongNoteOutcome { pending, perfect, good, missed }

class SongHit {
  const SongHit({
    required this.note,
    required this.judgment,
    required this.offset,
    required this.points,
  });

  final SongNote note;
  final SongNoteOutcome judgment;
  final Duration offset;
  final int points;
}

/// Deterministic rhythm scoring driven by the backing player's position.
///
/// No clock runs here: pausing audio also pauses the game. Rewound or stale
/// updates are ignored; a deliberate replay must call [reset].
class SongGame {
  SongGame(this.song);

  static const hitWindow = Duration(milliseconds: 280);
  static const perfectWindow = Duration(milliseconds: 110);

  final SongDefinition song;
  final Map<int, SongNoteOutcome> _outcomes = {};
  Duration _position = Duration.zero;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _hits = 0;
  int _misses = 0;
  SongHit? _lastHit;

  Duration get position => _position;
  int get score => _score;
  int get combo => _combo;
  int get bestCombo => _bestCombo;
  int get hits => _hits;
  int get misses => _misses;
  SongHit? get lastHit => _lastHit;
  bool get isComplete => _position >= song.duration;
  double get accuracy => _hits + _misses == 0 ? 0 : _hits / (_hits + _misses);
  Map<int, SongNoteOutcome> get outcomes => UnmodifiableMapView(_outcomes);

  SongNoteOutcome outcomeFor(int noteId) =>
      _outcomes[noteId] ?? SongNoteOutcome.pending;

  void update(Duration position) {
    if (position < _position) return;
    _position = position > song.duration ? song.duration : position;
    for (final note in song.notes) {
      if (outcomeFor(note.id) != SongNoteOutcome.pending) continue;
      if (_position - note.at > hitWindow || isComplete) {
        _outcomes[note.id] = SongNoteOutcome.missed;
        _misses++;
        _combo = 0;
      }
    }
  }

  /// Finds the nearest pending note. Omitting [lane] assists pitch selection.
  /// Early/late input outside the window does not penalize the patient.
  SongHit? hit(Duration position, {int? lane}) {
    if (position < _position || position < Duration.zero) return null;
    update(position);
    if (isComplete) return null;
    SongNote? nearest;
    var nearestOffsetUs = hitWindow.inMicroseconds + 1;
    for (final note in song.notes) {
      if (outcomeFor(note.id) != SongNoteOutcome.pending ||
          (lane != null && note.lane != lane)) {
        continue;
      }
      final offsetUs = (position - note.at).inMicroseconds.abs();
      if (offsetUs <= hitWindow.inMicroseconds && offsetUs < nearestOffsetUs) {
        nearest = note;
        nearestOffsetUs = offsetUs;
      }
    }
    if (nearest == null) return null;
    return _award(nearest, position);
  }

  /// A held target scores when a note reaches the line, never in advance.
  /// Consider the latest due note even when already hit, so repeated ticks or
  /// a clock jump cannot replay a backlog of older notes inside the window.
  SongHit? hitDue(Duration position) {
    if (position < _position || position < Duration.zero) return null;
    update(position);
    if (isComplete) return null;
    SongNote? latest;
    for (final note in song.notes) {
      if (note.at <= position && (latest == null || note.at > latest.at)) {
        latest = note;
      }
    }
    if (latest == null ||
        position - latest.at > hitWindow ||
        outcomeFor(latest.id) != SongNoteOutcome.pending) {
      return null;
    }
    return _award(latest, position);
  }

  SongHit _award(SongNote note, Duration position) {
    final nearestOffsetUs = (position - note.at).inMicroseconds.abs();
    final judgment = nearestOffsetUs <= perfectWindow.inMicroseconds
        ? SongNoteOutcome.perfect
        : SongNoteOutcome.good;
    _combo++;
    if (_combo > _bestCombo) _bestCombo = _combo;
    // Gentle combo bonuses reward continuity without multiplying a late error.
    final points =
        (judgment == SongNoteOutcome.perfect ? 100 : 70) +
        ((_combo - 1) ~/ 5).clamp(0, 3) * 10;
    _score += points;
    _hits++;
    _outcomes[note.id] = judgment;
    return _lastHit = SongHit(
      note: note,
      judgment: judgment,
      offset: position - note.at,
      points: points,
    );
  }

  void reset() {
    _position = Duration.zero;
    _score = 0;
    _combo = 0;
    _bestCombo = 0;
    _hits = 0;
    _misses = 0;
    _lastHit = null;
    _outcomes.clear();
  }
}
