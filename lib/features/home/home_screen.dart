import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../demo/demo_controller.dart';
import '../demo/motion_target_indicator.dart';
import '../demo/practice_play_view.dart';
import '../songs/song_catalog.dart';
import '../songs/song_play_card.dart';
import 'home_controller.dart';
import 'home_options.dart';
import 'home_panels.dart';

const demoMotion = <double>[
  0.2,
  0.55,
  0.62,
  0.45,
  0.25,
  0.3,
  0.6,
  0.82,
  0.7,
  0.4,
  0.35,
  0.55,
  0.65,
];

/// A fixed play workspace. Setup and secondary details open separate pages.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.controller,
    this.demo,
    this.batonConnected = false,
    this.motionSamples = demoMotion,
    this.motionIsLive = false,
    this.targetLow = 0.60,
    this.targetHigh = 0.70,
  });

  final HomeController? controller;
  final DemoController? demo;
  final bool batonConnected;
  final List<double> motionSamples;
  final bool motionIsLive;
  final double targetLow;
  final double targetHigh;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late HomeController _controller;

  bool get _batonConnected =>
      widget.demo?.connection.isConnected ?? widget.batonConnected;
  bool get _motionIsLive => widget.demo?.isLive ?? widget.motionIsLive;
  List<double> get _motionSamples {
    final samples = widget.demo?.samples;
    return samples == null || samples.isEmpty ? widget.motionSamples : samples;
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? HomeController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      } else {
        _controller.pauseSession();
      }
      _controller = widget.controller ?? HomeController();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (widget.demo != null) {
      if (state == AppLifecycleState.inactive) {
        widget.demo!.pause();
      } else {
        widget.demo!.suspend();
      }
    } else {
      _controller.pauseSession();
    }
  }

  void _openPanel(HomePanel panel) {
    if (widget.demo != null) {
      widget.demo!.pause();
    } else {
      _controller.pauseSession();
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => HomePanelScreen(
          home: _controller,
          demo: widget.demo,
          initialPanel: panel,
          samples: _motionSamples,
          motionIsLive: _motionIsLive,
          targetLow: widget.targetLow,
          targetHigh: widget.targetHigh,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.pauseSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: ListenableBuilder(
              listenable: widget.demo ?? _controller,
              builder: (context, _) => Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Rehab Rhapsody',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.display(21),
                          ),
                        ),
                        Semantics(
                          label: 'Baton settings',
                          button: true,
                          onTap: () => _openPanel(HomePanel.connection),
                          excludeSemantics: true,
                          child: Tooltip(
                            message: _batonConnected
                                ? 'Baton linked'
                                : 'Baton offline',
                            child: IconButton(
                              tooltip: 'Baton settings',
                              onPressed: () => _openPanel(HomePanel.connection),
                              color: _batonConnected
                                  ? AppTheme.mint
                                  : AppTheme.muted,
                              icon: Icon(
                                _batonConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_rounded,
                              ),
                            ),
                          ),
                        ),
                        Semantics(
                          label: 'Settings',
                          button: true,
                          onTap: () => _openPanel(HomePanel.settings),
                          excludeSemantics: true,
                          child: IconButton(
                            tooltip: 'Settings',
                            onPressed: () => _openPanel(HomePanel.settings),
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: _quickAction(
                            label: 'Choose play mode',
                            text: _controller.mode.label,
                            icon: Icons.sports_esports_rounded,
                            onTap: () => _openPanel(HomePanel.mode),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _quickAction(
                            label: 'Adjust target',
                            text:
                                'Target ${((widget.demo?.targetCenter ?? 0.65) * 100).round()}%',
                            icon: Icons.my_location_rounded,
                            onTap: () => _openPanel(HomePanel.target),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.demo?.message != null)
                    SizedBox(
                      height: 44,
                      child: Semantics(
                        liveRegion: true,
                        child: TextButton(
                          onPressed: () => _openPanel(HomePanel.connection),
                          child: Text(
                            widget.demo!.message!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(13),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(child: _workspace()),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _quickAction({
    required String label,
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.body(14),
      ),
    ),
  );

  Widget _workspace() {
    final demo = widget.demo;
    final session = demo?.songSession;
    if (_controller.mode == PlayMode.song && demo != null && session != null) {
      return SongPlayCard(
        songs: demoSongs,
        song: session.song,
        game: session.game,
        position: session.position,
        running: _controller.isRunning,
        starting: demo.starting,
        onPlayNote: demo.playSongNote,
        onSongChanged: demo.selectSong,
        onToggle: demo.toggleSession,
        onReset: demo.reset,
        onChooseSong: () => _openPanel(HomePanel.songs),
        targetIndicator: MotionTargetIndicator(
          targetLow: demo.targetLow,
          targetHigh: demo.targetHigh,
          currentLevel: demo.mapping?.normalizedLevel,
          isLive: demo.hasFreshTargetReading,
        ),
        inTarget: demo.inTarget,
        targetIsLive: demo.hasFreshTargetReading,
      );
    }
    return PracticePlayView(
      home: _controller,
      demo: demo,
      samples: _motionSamples,
      motionIsLive: _motionIsLive && _batonConnected,
      targetLow: demo?.targetLow ?? widget.targetLow,
      targetHigh: demo?.targetHigh ?? widget.targetHigh,
    );
  }
}
