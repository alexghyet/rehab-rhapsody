import 'dart:math' as math;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'song.dart';
import 'song_game.dart';

/// A bounded song stage: gameplay controls stay visible without scrolling.
class SongPlayCard extends StatelessWidget {
  const SongPlayCard({
    super.key,
    required this.songs,
    required this.song,
    required this.game,
    required this.position,
    required this.running,
    required this.starting,
    required this.onPlayNote,
    required this.onSongChanged,
    required this.onToggle,
    required this.onReset,
    this.onChooseSong,
    this.targetIndicator,
    this.inTarget = false,
    this.targetIsLive = false,
  });

  final List<SongDefinition> songs;
  final SongDefinition song;
  final SongGame game;
  final Duration position;
  final bool running;
  final bool starting;
  final VoidCallback onPlayNote;
  final ValueChanged<SongDefinition> onSongChanged;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final VoidCallback? onChooseSong;

  final Widget? targetIndicator;
  final bool inTarget;
  final bool targetIsLive;

  static const _stage = Color(0xFF21133D);
  static const _softWhite = Color(0xFFCEC3E9);

  int get _countIn {
    final beat = position.inMicroseconds / (60000000 / song.bpm);
    return (song.countInBeats - beat.floor()).clamp(0, song.countInBeats);
  }

  String get _toggleLabel => starting
      ? 'Cancel start'
      : running
      ? 'Pause song'
      : game.isComplete
      ? 'Play again'
      : position > Duration.zero
      ? 'Resume song'
      : 'Start song';

  String get _feedback {
    if (game.isComplete) return 'You made music!';
    if (starting) return 'Getting your song ready...';
    if (!running) {
      return position == Duration.zero ? 'Find your rhythm' : 'Take your time';
    }
    if (_countIn > 0) return 'Listen to the count-in';
    final hit = game.lastHit;
    if (hit != null &&
        position - hit.note.at < const Duration(milliseconds: 700)) {
      return hit.judgment == SongNoteOutcome.perfect
          ? 'Perfect timing!'
          : 'Nice rhythm!';
    }
    if (targetIsLive) {
      return inTarget ? 'In target - hold here' : 'Hold in target to hit notes';
    }
    return 'Keep the music going';
  }

  Future<void> _chooseSong(BuildContext context) async {
    if (onChooseSong != null) {
      onChooseSong!();
      return;
    }
    final chosen = await showDialog<SongDefinition>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose a song', style: AppTheme.display(20)),
              const SizedBox(height: 8),
              for (final item in songs)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
                  onPressed: () => Navigator.pop(context, item),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) onSongChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final progress = song.duration.inMicroseconds == 0
        ? 0.0
        : (position.inMicroseconds / song.duration.inMicroseconds).clamp(
            0.0,
            1.0,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _stage,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Semantics(
              button: true,
              enabled: !starting,
              label: 'Choose song. ${song.title}, ${song.bpm} beats per minute',
              excludeSemantics: true,
              onTap: starting ? null : () => _chooseSong(context),
              child: SizedBox(
                height: 44,
                child: TextButton(
                  key: const Key('song-chooser'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF352453),
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: starting ? null : () => _chooseSong(context),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.display(17, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more_rounded, size: 24),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 36,
              child: Row(
                spacing: 6,
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Score',
                      value: '${game.score}',
                      icon: Icons.star_rounded,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Combo',
                      value: '${game.combo}x',
                      icon: Icons.bolt_rounded,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'Notes hit',
                      value: '${game.hits}/${song.notes.length}',
                      icon: Icons.music_note_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                _feedback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTheme.display(14, color: const Color(0xFFFFD88A)),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Expanded(child: _highway()),
                  if (targetIndicator != null)
                    SizedBox(width: 26, child: targetIndicator),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              semanticsLabel: 'Song progress',
              borderRadius: BorderRadius.circular(6),
              minHeight: 4,
              backgroundColor: const Color(0xFF483364),
              color: const Color(0xFF82E3CB),
            ),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('song-play-note'),
                      onPressed: running && !starting && !game.isComplete
                          ? onPlayNote
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF82E3CB),
                        foregroundColor: const Color(0xFF143D37),
                        disabledBackgroundColor: const Color(0xFF4B4A60),
                        disabledForegroundColor: const Color(0xFFD0CADB),
                        minimumSize: const Size(44, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: AppTheme.display(16),
                      ),
                      child: const Text(
                        'Play note',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Semantics(
                      button: true,
                      label: _toggleLabel,
                      onTap: onToggle,
                      excludeSemantics: true,
                      child: IconButton.filled(
                        key: const Key('song-toggle'),
                        onPressed: onToggle,
                        tooltip: _toggleLabel,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.grape,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          starting
                              ? Icons.close_rounded
                              : running
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Semantics(
                      button: true,
                      label: 'Restart',
                      onTap: onReset,
                      excludeSemantics: true,
                      child: IconButton.outlined(
                        key: const Key('song-restart'),
                        onPressed: onReset,
                        tooltip: 'Restart',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF8876A8)),
                        ),
                        icon: const Icon(Icons.replay_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highway() => Semantics(
    label: 'Song note highway. Hold the baton in the target zone as notes reach the bright line. All four colors use the same target or Play note button.',
    image: true,
    container: true,
    explicitChildNodes: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            key: const Key('song-highway'),
            painter: _NoteHighwayPainter(
              song: song,
              position: position,
              outcomes: Map.of(game.outcomes),
            ),
          ),
          if (running && _countIn > 0)
            Center(
              child: Semantics(
                liveRegion: true,
                label: 'Count-in $_countIn',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$_countIn',
                      style: AppTheme.display(64, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          if (!running || game.isComplete)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _stage.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            game.isComplete
                                ? 'Best combo ${game.bestCombo}x'
                                : position > Duration.zero
                                ? 'Paused'
                                : 'Ready when you are',
                            style: AppTheme.body(16, color: Colors.white),
                          ),
                          if (game.isComplete)
                            Text(
                              '${(game.accuracy * 100).round()}% hit',
                              style: AppTheme.body(14, color: _softWhite),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF352453),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            children: [
              Icon(icon, size: 15, color: SongPlayCard._softWhite),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NoteHighwayPainter extends CustomPainter {
  _NoteHighwayPainter({
    required this.song,
    required this.position,
    required this.outcomes,
  });
  final SongDefinition song;
  final Duration position;
  final Map<int, SongNoteOutcome> outcomes;

  static const _laneColors = [
    Color(0xFF82E3CB),
    Color(0xFFFFD88A),
    Color(0xFFFF8BAE),
    Color(0xFFB6A1FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // A host can briefly collapse the stage during a resize or route transition.
    if (size.width <= 0 || size.height <= 50) return;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF150D29),
    );
    final hitY = size.height - 36;
    const horizon = 14.0;
    final travel = hitY - horizon;
    final lookAheadUs = 60000000 / song.bpm * 3.5;

    double left(double y) =>
        size.width * (0.16 - 0.12 * (y / hitY).clamp(0, 1));
    double right(double y) => size.width - left(y);
    double laneX(int lane, double y) =>
        left(y) + (right(y) - left(y)) * (lane + 0.5) / 4;

    for (var lane = 0; lane < 4; lane++) {
      final path = Path()
        ..moveTo(left(0) + (right(0) - left(0)) * lane / 4, 0)
        ..lineTo(left(0) + (right(0) - left(0)) * (lane + 1) / 4, 0)
        ..lineTo(
          left(size.height) +
              (right(size.height) - left(size.height)) * (lane + 1) / 4,
          size.height,
        )
        ..lineTo(
          left(size.height) +
              (right(size.height) - left(size.height)) * lane / 4,
          size.height,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = _laneColors[lane].withValues(alpha: 0.07),
      );
    }
    for (var lane = 0; lane <= 4; lane++) {
      canvas.drawLine(
        Offset(left(0) + (right(0) - left(0)) * lane / 4, 0),
        Offset(
          left(size.height) +
              (right(size.height) - left(size.height)) * lane / 4,
          size.height,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..strokeWidth = 1,
      );
    }

    final beatUs = 60000000 / song.bpm;
    final firstBeat = math.max(0, (position.inMicroseconds / beatUs).floor());
    for (var beat = firstBeat; beat <= firstBeat + 5; beat++) {
      final y =
          hitY -
          (beat * beatUs - position.inMicroseconds) / lookAheadUs * travel;
      if (y < 0 || y > size.height) continue;
      canvas.drawLine(
        Offset(left(y), y),
        Offset(right(y), y),
        Paint()
          ..color = Colors.white.withValues(
            alpha: beat % song.beatsPerBar == 0 ? 0.2 : 0.08,
          )
          ..strokeWidth = 1,
      );
    }

    canvas.drawLine(
      Offset(left(hitY), hitY),
      Offset(right(hitY), hitY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..strokeWidth = 6,
    );
    canvas.drawLine(
      Offset(left(hitY), hitY),
      Offset(right(hitY), hitY),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
    for (var lane = 0; lane < 4; lane++) {
      final center = Offset(laneX(lane, hitY), hitY);
      canvas.drawCircle(center, 15, Paint()..color = const Color(0xFF21133D));
      canvas.drawCircle(
        center,
        15,
        Paint()
          ..color = _laneColors[lane]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    for (final note in song.notes) {
      final untilUs = (note.at - position).inMicroseconds;
      if (untilUs > lookAheadUs || untilUs < -400000) continue;
      final outcome = outcomes[note.id] ?? SongNoteOutcome.pending;
      if (outcome == SongNoteOutcome.missed) continue;
      final color = _laneColors[note.lane % _laneColors.length];
      if (outcome != SongNoteOutcome.pending) {
        final fade = (1 - math.max(0, -untilUs) / 400000).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(laneX(note.lane, hitY), hitY),
          20 + (1 - fade) * 10,
          Paint()
            ..color = color.withValues(alpha: fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        continue;
      }
      final y = hitY - untilUs / lookAheadUs * travel;
      final center = Offset(laneX(note.lane, y), y);
      final radius = 9.0 + 5.0 * (y / hitY).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        radius + 5,
        Paint()..color = color.withValues(alpha: 0.12),
      );
      canvas.drawCircle(
        center.translate(0, 3),
        radius,
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      );
      canvas.drawCircle(center, radius, Paint()..color = color);
      canvas.drawCircle(
        center.translate(-2, -3),
        radius * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NoteHighwayPainter oldDelegate) =>
      song != oldDelegate.song ||
      position != oldDelegate.position ||
      !mapEquals(outcomes, oldDelegate.outcomes);
}
