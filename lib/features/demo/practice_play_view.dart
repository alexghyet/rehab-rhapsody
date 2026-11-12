import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../home/home_controller.dart';
import '../home/home_options.dart';
import '../home/widgets/motion_chart.dart';
import '../motion/motion_mapper.dart';
import '../music/music_note.dart';
import 'demo_controller.dart';

/// The practice workspace uses the available screen height, without a scroll
/// surface. Configuration and connection controls belong to the parent screen.
class PracticePlayView extends StatelessWidget {
  const PracticePlayView({
    super.key,
    required this.home,
    required this.samples,
    required this.motionIsLive,
    required this.targetLow,
    required this.targetHigh,
    this.demo,
  });

  final HomeController home;
  final DemoController? demo;
  final List<double> samples;
  final bool motionIsLive;
  final double targetLow;
  final double targetHigh;

  String get _guidance => switch (home.mode) {
    PlayMode.guided =>
      'Next: ${MusicNote(demo?.targetMidi ?? 60).label} · '
          'Step ${(demo?.guidedStep ?? 0) % DemoController.guidedMelody.length + 1} '
          'of ${DemoController.guidedMelody.length}',
    PlayMode.rhythm =>
      'Beat ${demo == null || demo!.beat == 0 ? 1 : (demo!.beat - 1) % 4 + 1} · '
          '${home.tempo.round()} BPM',
    PlayMode.free || PlayMode.song => 'Move gently or tap a note',
  };

  void _toggle() {
    if (demo != null) {
      unawaited(demo!.toggleSession());
    } else {
      home.toggleSession();
    }
  }

  void _reset() {
    if (demo != null) {
      demo!.reset();
    } else {
      home.pauseSession();
      home.resetSession();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demo ?? home,
    builder: (context, _) {
      final note = home.currentNote;
      final starting = demo?.starting == true;
      final action = starting
          ? 'Cancel start'
          : home.isRunning
          ? 'Pause session'
          : 'Start session';
      final guidance = _guidance;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Semantics(
                key: const Key('practice-current-note'),
                container: true,
                liveRegion: true,
                label: note == null
                    ? 'Current note, no note playing'
                    : 'Current note ${note.spokenLabel}',
                excludeSemantics: true,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          'Current note',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(12, color: AppTheme.muted),
                        ),
                      ),
                      Text(
                        note?.displayLabel ?? '—',
                        maxLines: 1,
                        style: AppTheme.display(20, color: AppTheme.grape),
                      ),
                    ],
                  ),
                ),
              ),
              Semantics(
                label: starting ? 'Preparing sound' : guidance,
                excludeSemantics: true,
                child: Text(
                  starting ? 'Preparing sound…' : guidance,
                  key: const Key('practice-guidance'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(13, color: AppTheme.grape),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 3,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Arm motion',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(11, color: AppTheme.muted),
                          ),
                        ),
                        Text(
                          motionIsLive ? 'Live' : 'Preview',
                          style: AppTheme.body(10, color: AppTheme.mintInk),
                        ),
                      ],
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final scale = MediaQuery.textScalerOf(context);
                          // Tiny landscape hosts can provide less space than a
                          // chart label. Its semantic description stays intact.
                          final chartScale =
                              constraints.maxHeight >= scale.scale(11) + 20
                              ? scale
                              : TextScaler.noScaling;
                          return Semantics(
                            image: true,
                            label: motionIsLive
                                ? 'Live arm movement compared with the target range'
                                : 'Sample arm movement compared with the target range',
                            child: ClipRect(
                              child: CustomPaint(
                                key: const Key('practice-motion-chart'),
                                painter: MotionChartPainter(
                                  samples: samples,
                                  targetLow: targetLow,
                                  targetHigh: targetHigh,
                                  textScaler: chartScale,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              for (final row in [
                MotionMapper.scale.take(4),
                MotionMapper.scale.skip(4),
              ])
                SizedBox(
                  height: 48,
                  child: Row(
                    spacing: 6,
                    children: [
                      for (final midi in row) Expanded(child: _notePad(midi)),
                    ],
                  ),
                ),
              SizedBox(
                height: 48,
                child: Row(
                  spacing: 6,
                  children: [
                    Semantics(
                      button: true,
                      label: action,
                      onTap: _toggle,
                      excludeSemantics: true,
                      child: IconButton.filled(
                        key: const Key('practice-toggle'),
                        tooltip: action,
                        onPressed: _toggle,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: Icon(
                          starting
                              ? Icons.close_rounded
                              : home.isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        label: 'Session time ${home.formattedTime}',
                        excludeSemantics: true,
                        child: Text(
                          home.formattedTime,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(13, color: AppTheme.muted),
                        ),
                      ),
                    ),
                    IconButton.outlined(
                      key: const Key('practice-reset'),
                      tooltip: 'Reset timer',
                      onPressed: home.isRunning || home.canReset || starting
                          ? _reset
                          : null,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: const Icon(Icons.restart_alt_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _notePad(int midi) {
    final note = MusicNote(midi);
    final highlighted =
        home.mode == PlayMode.guided && (demo?.targetMidi ?? 60) == midi;
    final play = demo == null ? null : () => unawaited(demo!.playPad(midi));
    return Semantics(
      button: true,
      enabled: play != null,
      label: 'Play ${note.spokenLabel}',
      excludeSemantics: true,
      onTap: play,
      child: OutlinedButton(
        key: ValueKey('practice-note-$midi'),
        onPressed: play,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          minimumSize: const Size(44, 48),
          backgroundColor: highlighted ? AppTheme.mintSoft : AppTheme.grapeSoft,
          foregroundColor: AppTheme.grape,
        ),
        child: Text(
          note.displayLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.display(20),
        ),
      ),
    );
  }
}
