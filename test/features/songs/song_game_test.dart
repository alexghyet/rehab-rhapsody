import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/songs/song.dart';
import 'package:rehab_rhapsody/features/songs/song_catalog.dart';
import 'package:rehab_rhapsody/features/songs/song_game.dart';

void main() {
  test('held targets wait until the onset and award a due note only once', () {
    final game = SongGame(_song());
    expect(game.hitDue(const Duration(microseconds: 999999)), isNull);
    expect(game.hits, 0);
    expect(game.misses, 0);

    final hit = game.hitDue(const Duration(seconds: 1));
    expect(hit?.note.id, 0);
    expect(hit?.offset, Duration.zero);
    expect(hit?.judgment, SongNoteOutcome.perfect);
    expect(game.hitDue(const Duration(seconds: 1)), isNull);
    expect(game.hitDue(const Duration(milliseconds: 1100)), isNull);
    expect(game.hits, 1);
    expect(game.score, 100);
    expect(game.hitDue(const Duration(seconds: 2))?.note.id, 1);
    expect(game.combo, 2);
  });

  test(
    'held targets include the late boundary without extending the window',
    () {
      final perfect = SongGame(_song());
      expect(
        perfect.hitDue(const Duration(milliseconds: 1110))?.judgment,
        SongNoteOutcome.perfect,
      );
      final good = SongGame(_song());
      expect(
        good.hitDue(const Duration(milliseconds: 1111))?.judgment,
        SongNoteOutcome.good,
      );
      final boundary = SongGame(_song());
      final hit = boundary.hitDue(const Duration(milliseconds: 1280));
      expect(hit?.note.id, 0);
      expect(hit?.offset, const Duration(milliseconds: 280));
      expect(hit?.judgment, SongNoteOutcome.good);
      final expired = SongGame(_song());
      expect(expired.hitDue(const Duration(milliseconds: 1281)), isNull);
      expect(expired.outcomeFor(0), SongNoteOutcome.missed);
      expect(expired.hits, 0);
      expect(expired.misses, 1);
    },
  );

  test(
    'a clock jump misses expired notes and awards only the current due note',
    () {
      final game = SongGame(_song());
      final hit = game.hitDue(const Duration(milliseconds: 3050));
      expect(hit?.note.id, 2);
      expect(game.outcomeFor(0), SongNoteOutcome.missed);
      expect(game.outcomeFor(1), SongNoteOutcome.missed);
      expect(game.hits, 1);
      expect(game.misses, 2);
      expect(game.combo, 1);
      expect(game.hitDue(const Duration(milliseconds: 3050)), isNull);
      expect(game.hitDue(const Duration(seconds: 4)), isNull);
      expect(game.isComplete, isTrue);
      expect(game.hits, 1);
    },
  );

  test('dense due notes cannot replay an older backlog on later ticks', () {
    final game = SongGame(_song(spacingMs: 100));
    expect(game.hitDue(const Duration(milliseconds: 1250))?.note.id, 2);
    // Both earlier notes remain inside the late window, but scoring the newest
    // note must not let subsequent ticks sweep backward through them.
    expect(game.outcomeFor(0), SongNoteOutcome.pending);
    expect(game.outcomeFor(1), SongNoteOutcome.pending);
    expect(game.hitDue(const Duration(milliseconds: 1250)), isNull);
    expect(game.hitDue(const Duration(milliseconds: 1260)), isNull);
    expect(game.hits, 1);
    expect(game.score, 100);
    game.update(game.song.duration);
    expect(game.misses, 2);
  });

  test('a manually hit latest note cannot unlock an older automatic hit', () {
    final game = SongGame(_song(spacingMs: 100));
    expect(game.hit(const Duration(milliseconds: 1250))?.note.id, 2);
    expect(game.hitDue(const Duration(milliseconds: 1250)), isNull);
    expect(game.hits, 1);
    expect(game.outcomeFor(0), SongNoteOutcome.pending);
    expect(game.outcomeFor(1), SongNoteOutcome.pending);
  });

  test('held targets reject stale positions and replay only after reset', () {
    final game = SongGame(_song());
    expect(game.hitDue(const Duration(microseconds: -1)), isNull);
    game.update(const Duration(milliseconds: 1500));
    expect(game.hitDue(const Duration(seconds: 1)), isNull);
    expect(game.position, const Duration(milliseconds: 1500));
    expect(game.misses, 1);
    game.reset();
    expect(game.hitDue(const Duration(seconds: 1))?.note.id, 0);
    expect(game.hits, 1);
    expect(game.misses, 0);
  });

  test('timing-only input plays the nearest note once regardless of lane', () {
    final game = SongGame(_song());
    final hit = game.hit(const Duration(milliseconds: 1030));
    expect(hit?.note.midiNote, 64);
    expect(hit?.judgment, SongNoteOutcome.perfect);
    expect(hit?.offset, const Duration(milliseconds: 30));
    expect(game.score, 100);
    expect(game.hit(const Duration(milliseconds: 1040)), isNull);
    expect(game.hits, 1);
    expect(game.combo, 1);
  });

  test('hit and perfect windows include their exact boundaries', () {
    for (final milliseconds in [-280, 280]) {
      final game = SongGame(_song());
      final hit = game.hit(Duration(milliseconds: 1000 + milliseconds));
      expect(hit?.judgment, SongNoteOutcome.good);
      expect(hit?.points, 70);
    }
    for (final milliseconds in [-110, 110]) {
      final game = SongGame(_song());
      final hit = game.hit(Duration(milliseconds: 1000 + milliseconds));
      expect(hit?.judgment, SongNoteOutcome.perfect);
    }
    final early = SongGame(_song());
    expect(early.hit(const Duration(milliseconds: 719)), isNull);
    expect(early.misses, 0);
    final late = SongGame(_song());
    expect(late.hit(const Duration(milliseconds: 1281)), isNull);
    expect(late.misses, 1);
  });

  test('nearest target wins overlapping windows and ties prefer earlier', () {
    final song = _song(spacingMs: 300);
    final nearest = SongGame(song);
    expect(nearest.hit(const Duration(milliseconds: 1210))?.note.id, 1);
    final tie = SongGame(song);
    expect(tie.hit(const Duration(milliseconds: 1150))?.note.id, 0);
  });

  test('optional lane filter never awards a different lane', () {
    final game = SongGame(_song());
    expect(game.hit(const Duration(seconds: 1), lane: 3), isNull);
    expect(game.hits, 0);
    expect(game.hit(const Duration(seconds: 1), lane: 0)?.note.id, 0);
  });

  test('misses break combo once, while preserving best combo and score', () {
    final game = SongGame(_song());
    game.hit(const Duration(seconds: 1));
    game.hit(const Duration(seconds: 2));
    expect(game.bestCombo, 2);
    game.update(const Duration(milliseconds: 3281));
    game.update(const Duration(milliseconds: 3300));
    expect(game.misses, 1);
    expect(game.combo, 0);
    expect(game.bestCombo, 2);
    expect(game.score, 200);
    expect(game.accuracy, closeTo(2 / 3, 0.0001));
    expect(game.outcomeFor(2), SongNoteOutcome.missed);
  });

  test('stale positions cannot rewind the game or score an expired note', () {
    final game = SongGame(_song());
    game.update(const Duration(milliseconds: 1281));
    game.update(const Duration(seconds: 1));
    expect(game.position, const Duration(milliseconds: 1281));
    expect(game.hit(const Duration(seconds: 1)), isNull);
    expect(game.hits, 0);
    expect(game.misses, 1);
  });

  test('completion consumes remaining misses and reset enables a replay', () {
    final game = SongGame(_song());
    game.hit(const Duration(seconds: 1));
    game.update(const Duration(hours: 1));
    expect(game.position, game.song.duration);
    expect(game.isComplete, isTrue);
    expect(game.hits + game.misses, game.song.notes.length);
    expect(game.hit(const Duration(hours: 1)), isNull);
    game.reset();
    expect(game.position, Duration.zero);
    expect(game.isComplete, isFalse);
    expect(game.hits, 0);
    expect(game.misses, 0);
    expect(game.combo, 0);
    expect(game.bestCombo, 0);
    expect(game.score, 0);
    expect(game.lastHit, isNull);
    expect(game.outcomes, isEmpty);
    expect(game.hit(const Duration(seconds: 1)), isNotNull);
  });

  test('score bonuses are bounded and outcome snapshots cannot be mutated', () {
    final game = SongGame(_song(count: 24));
    for (final note in game.song.notes) {
      final hit = game.hit(note.at)!;
      expect(hit.points, inInclusiveRange(100, 130));
    }
    expect(game.lastHit?.points, 130);
    expect(game.combo, 24);
    expect(game.accuracy, 1);
    expect(() => game.outcomes.clear(), throwsUnsupportedError);
  });

  test('bundled charts and audio match the generated timing manifest', () {
    final manifest = jsonDecode(
      File('assets/audio/songs/manifest.json').readAsStringSync(),
    ) as List<dynamic>;
    expect(demoSongs, hasLength(3));
    expect(demoSongs.map((song) => song.id).toSet(), hasLength(3));
    for (final song in demoSongs) {
      final entry = manifest.cast<Map<String, dynamic>>().singleWhere(
        (entry) => entry['id'] == song.id,
      );
      expect(song.bpm, entry['bpm']);
      expect(song.duration.inMicroseconds, entry['duration_us']);
      expect(song.duration.inSeconds, inInclusiveRange(30, 60));
      expect(song.countInBeats, 4);
      expect(song.notes.first.at, song.countInDuration);
      final events = entry['notes'] as List<dynamic>;
      expect(song.notes.length, events.length);
      final ids = <int>{};
      Duration? previous;
      for (var index = 0; index < events.length; index++) {
        final note = song.notes[index];
        final event = events[index] as Map<String, dynamic>;
        expect(ids.add(note.id), isTrue);
        expect(note.at.inMicroseconds, event['at']);
        expect(note.duration.inMicroseconds, event['duration']);
        expect(note.midiNote, event['midi']);
        expect(note.lane, event['lane']);
        expect(note.midiNote, isIn([60, 62, 64, 65, 67, 69, 71, 72]));
        expect(note.lane, inInclusiveRange(0, 3));
        expect(note.duration, greaterThan(Duration.zero));
        expect(note.at + note.duration, lessThan(song.duration));
        if (previous != null) expect(note.at, greaterThan(previous));
        previous = note.at;
      }
      final bytes = File('assets/${song.backingAsset}').readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
      expect(header.getUint16(20, Endian.little), 1); // Uncompressed PCM.
      expect(header.getUint16(22, Endian.little), 1); // Mono.
      expect(header.getUint16(34, Endian.little), 16);
      final sampleRate = header.getUint32(24, Endian.little);
      final frames = header.getUint32(40, Endian.little) ~/ 2;
      expect(sampleRate, entry['sample_rate']);
      expect(frames, entry['frames']);
      expect(
        frames / sampleRate,
        closeTo(song.duration.inMicroseconds / 1e6, 1 / sampleRate),
      );
    }
  });
}

SongDefinition _song({int spacingMs = 1000, int count = 3}) => SongDefinition(
  id: 'test',
  title: 'Test song',
  subtitle: 'Test',
  composer: 'Test',
  bpm: 60,
  duration: Duration(milliseconds: 1000 + count * spacingMs),
  backingAsset: 'audio/songs/test.wav',
  notes: List.generate(
    count,
    (index) => SongNote(
      id: index,
      midiNote: 64,
      lane: index % 4,
      at: Duration(milliseconds: 1000 + index * spacingMs),
      duration: const Duration(milliseconds: 300),
    ),
  ),
);
