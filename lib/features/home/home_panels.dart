import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../demo/demo_controller.dart';
import '../demo/motion_target_indicator.dart';
import '../songs/song_catalog.dart';
import 'home_controller.dart';
import 'home_options.dart';
import 'widgets/motion_chart.dart';

enum HomePanel {
  settings('Settings', Icons.settings_rounded),
  mode('Mode of play', Icons.sports_esports_rounded),
  instrument('Instrument', Icons.piano),
  target('Target height', Icons.my_location_rounded),
  volume('Volume', Icons.volume_up_rounded),
  tempo('Tempo', Icons.speed_rounded),
  connection('Your baton', Icons.bluetooth_rounded),
  motion('Arm motion', Icons.show_chart_rounded),
  songs('Choose a song', Icons.library_music_rounded),
  help('How to play', Icons.help_outline_rounded);

  const HomePanel(this.title, this.icon);
  final String title;
  final IconData icon;
}

/// Full-screen, button-navigated settings: each task fits without a scroll view.
class HomePanelScreen extends StatefulWidget {
  const HomePanelScreen({
    super.key,
    required this.home,
    required this.initialPanel,
    required this.samples,
    required this.motionIsLive,
    required this.targetLow,
    required this.targetHigh,
    this.demo,
  });

  final HomeController home;
  final DemoController? demo;
  final HomePanel initialPanel;
  final List<double> samples;
  final bool motionIsLive;
  final double targetLow;
  final double targetHigh;

  @override
  State<HomePanelScreen> createState() => _HomePanelScreenState();
}

class _HomePanelScreenState extends State<HomePanelScreen> {
  late HomePanel _panel = widget.initialPanel;
  int _helpPage = 0;

  static const _help = [
    'Power your baton and disconnect LightBlue before connecting it here.',
    'In Songs, hold inside the target zone. Notes play automatically as they reach the line.',
    'Use Target height or Use current position to choose a comfortable baton angle.',
    'Free play and Guided use tilt for pitch and rotation to play. Rhythm plays moving readings on the beat.',
    'Pause stops sound. Closing settings or returning from the background leaves the session paused.',
  ];

  void _show(HomePanel panel) => setState(() => _panel = panel);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (_panel != HomePanel.settings)
                        _iconAction(
                          label: 'Back to settings',
                          onTap: () => _show(HomePanel.settings),
                          icon: Icons.arrow_back_rounded,
                        ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _panel.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.display(20),
                          ),
                        ),
                      ),
                      _iconAction(
                        label: 'Close settings',
                        onTap: () => Navigator.of(context).pop(),
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListenableBuilder(
                    listenable: widget.demo ?? widget.home,
                    builder: (context, _) => _body(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _iconAction({
    required String label,
    required VoidCallback onTap,
    required IconData icon,
  }) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: IconButton(tooltip: label, onPressed: onTap, icon: Icon(icon)),
  );

  Widget _body() => switch (_panel) {
    HomePanel.settings => _menu(),
    HomePanel.mode => _choices([
      for (final mode in PlayMode.values)
        _choice(
          mode.label,
          Icons.music_note_rounded,
          widget.home.mode == mode,
          () {
            widget.home.selectMode(mode);
            Navigator.of(context).pop();
          },
        ),
    ]),
    HomePanel.instrument => _choices([
      for (final instrument in Instrument.values)
        _choice(
          instrument.label,
          instrument.icon,
          widget.home.instrument == instrument,
          () => widget.home.selectInstrument(instrument),
        ),
    ]),
    HomePanel.volume => _slider(
      label: 'Volume',
      value: widget.home.volume,
      min: 0,
      max: 100,
      unit: '%',
      onChanged: widget.home.setVolume,
    ),
    HomePanel.tempo => _slider(
      label: 'Tempo',
      value: widget.home.mode == PlayMode.song
          ? widget.demo?.songSession?.song.bpm.toDouble() ?? widget.home.tempo
          : widget.home.tempo,
      min: 40,
      max: 140,
      unit: ' BPM',
      onChanged: widget.home.mode == PlayMode.song
          ? null
          : widget.home.setTempo,
    ),
    HomePanel.target => _target(),
    HomePanel.connection => _connection(),
    HomePanel.motion => _motion(),
    HomePanel.songs => _songs(),
    HomePanel.help => _helpView(),
  };

  Widget _menu() {
    const panels = [
      HomePanel.mode,
      HomePanel.instrument,
      HomePanel.target,
      HomePanel.volume,
      HomePanel.tempo,
      HomePanel.connection,
      HomePanel.motion,
      HomePanel.help,
    ];
    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _show(panels[row * 2 + column]),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (MediaQuery.textScalerOf(context).scale(14) <=
                              20) ...[
                            Icon(panels[row * 2 + column].icon, size: 24),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            panels[row * 2 + column].title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: AppTheme.body(14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _choices(List<Widget> choices) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < choices.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        Expanded(child: choices[i]),
      ],
    ],
  );

  Widget _choice(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) => Semantics(
    selected: selected,
    child: FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: selected ? AppTheme.grapeSoft : Colors.white,
        side: BorderSide(
          color: selected ? AppTheme.grape : Colors.transparent,
          width: 2,
        ),
      ),
      icon: Icon(selected ? Icons.check_circle_rounded : icon),
      label: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: AppTheme.body(18),
      ),
    ),
  );

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double>? onChanged,
  }) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(_panel.icon, size: 48, color: AppTheme.grape),
      const SizedBox(height: 16),
      Text(
        '${value.round()}$unit',
        textAlign: TextAlign.center,
        style: AppTheme.display(34),
      ),
      const SizedBox(height: 16),
      Semantics(
        label: label,
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          semanticFormatterCallback: (value) => '${value.round()}$unit',
          onChanged: onChanged,
        ),
      ),
      if (onChanged == null)
        Text(
          'Song tempo follows its backing track.',
          textAlign: TextAlign.center,
          style: AppTheme.body(16, color: AppTheme.muted),
        ),
    ],
  );

  Widget _target() {
    final demo = widget.demo;
    final live = demo?.hasFreshTargetReading == true;
    final level = live ? demo!.mapping!.normalizedLevel : null;
    final low = demo?.targetLow ?? widget.targetLow;
    final high = demo?.targetHigh ?? widget.targetHigh;
    final center = demo?.targetCenter ?? (low + high) / 2;
    final status = level == null
        ? 'Waiting for baton'
        : demo!.inTarget
        ? 'In target'
        : level < low
        ? 'Higher'
        : 'Lower';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set a comfortable angle',
          textAlign: TextAlign.center,
          style: AppTheme.body(16),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 64,
              child: MotionTargetIndicator(
                targetLow: low,
                targetHigh: high,
                currentLevel: level,
                isLive: live,
              ),
            ),
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppTheme.body(16, color: AppTheme.mintInk),
          ),
        ),
        Text(
          '${(center * 100).round()}%',
          textAlign: TextAlign.center,
          style: AppTheme.display(26),
        ),
        Semantics(
          label: 'Target height',
          child: Slider(
            key: const Key('target-height-slider'),
            value: center.clamp(
              DemoController.minimumTargetCenter,
              DemoController.maximumTargetCenter,
            ),
            min: DemoController.minimumTargetCenter,
            max: DemoController.maximumTargetCenter,
            divisions: 90,
            semanticFormatterCallback: (value) =>
                '${(value * 100).round()} percent',
            onChanged: demo?.setTargetCenter,
          ),
        ),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: live ? demo!.useCurrentPositionAsTarget : null,
            icon: const Icon(Icons.my_location_rounded),
            label: const Text(
              'Use current position',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _connection() {
    final demo = widget.demo;
    final connection = demo?.connection;
    final connected = connection?.isConnected == true;
    final busy = connection?.isBusy == true;
    final label = connected
        ? 'Disconnect baton'
        : busy
        ? 'Cancel connection'
        : 'Connect baton';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Icon(
          connected ? Icons.bluetooth_connected : Icons.bluetooth_rounded,
          size: 48,
          color: connected ? AppTheme.mint : AppTheme.grape,
        ),
        const SizedBox(height: 12),
        Text(
          connected
              ? 'Baton linked'
              : busy
              ? 'Connecting…'
              : 'Baton not connected',
          maxLines: 2,
          textAlign: TextAlign.center,
          style: AppTheme.display(22),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Text(
                demo?.message ??
                    connection?.message ??
                    (demo?.isLive == true
                        ? '${connection?.deviceName ?? 'Rehab Rhapsody'}\n${demo!.sampleRate.round()} readings/s'
                        : connected
                        ? 'Waiting for motion readings.'
                        : 'Power the baton and disconnect LightBlue before connecting.'),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTheme.body(16, color: AppTheme.muted),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: demo == null
                ? null
                : () => unawaited(
                    connected || busy ? demo.disconnect() : demo.connect(),
                  ),
            icon: const Icon(Icons.bluetooth_rounded),
            label: Text(label),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => _show(HomePanel.help),
            child: const Text('Connection help'),
          ),
        ),
      ],
    );
  }

  Widget _motion() {
    final demo = widget.demo;
    final note = widget.home.currentNote;
    final live = demo?.isLive ?? widget.motionIsLive;
    final samples = demo?.samples;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: note == null
              ? 'Current note, no note playing'
              : 'Current note ${note.spokenLabel}',
          child: Text(
            note?.displayLabel ?? 'No note playing',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: AppTheme.display(26),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Semantics(
            image: true,
            label: live ? 'Live arm motion' : 'Preview arm motion',
            child: ClipRect(
              child: CustomPaint(
                painter: MotionChartPainter(
                  samples: samples != null && samples.isNotEmpty
                      ? samples
                      : widget.samples,
                  targetLow: demo?.targetLow ?? widget.targetLow,
                  targetHigh: demo?.targetHigh ?? widget.targetHigh,
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          live
              ? 'Live · ${demo?.sampleRate.round() ?? 0} readings/s'
              : 'Preview',
          textAlign: TextAlign.center,
          style: AppTheme.body(16),
        ),
      ],
    );
  }

  Widget _songs() => _choices([
    for (final song in demoSongs)
      _choice(
        song.title,
        Icons.music_note_rounded,
        widget.demo?.songSession?.song.id == song.id,
        () {
          widget.demo?.selectSong(song);
          Navigator.of(context).pop();
        },
      ),
  ]);

  Widget _helpView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Center(
          child: Text(
            _help[_helpPage],
            textAlign: TextAlign.center,
            style: AppTheme.body(18),
          ),
        ),
      ),
      Text(
        '${_helpPage + 1} / ${_help.length}',
        textAlign: TextAlign.center,
        style: AppTheme.body(14, color: AppTheme.muted),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _helpPage == 0
                    ? null
                    : () => setState(() => _helpPage--),
                child: const Text('Previous'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _helpPage == _help.length - 1
                    ? () => _show(HomePanel.settings)
                    : () => setState(() => _helpPage++),
                child: Text(_helpPage == _help.length - 1 ? 'Done' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
