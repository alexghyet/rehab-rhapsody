import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/decorative_bubble.dart';
import 'home_controller.dart';
import 'widgets/home_header.dart';
import 'widgets/motion_card.dart';
import 'widgets/session_card.dart';
import 'widgets/setup_card.dart';
import 'widgets/sliders_card.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.controller,
    this.batonConnected = false,
    this.motionSamples = demoMotion,
    this.motionIsLive = false,
    this.targetLow = 0.45,
    this.targetHigh = 0.8,
  });

  final HomeController? controller;
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
    if (state != AppLifecycleState.resumed) _controller.pauseSession();
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -70,
            child: DecorativeBubble(size: 220, color: AppTheme.lilac),
          ),
          const Positioned(
            top: 300,
            left: -50,
            child: DecorativeBubble(size: 90, color: AppTheme.peach),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Always scroll: small iPhones and Dynamic Type need more room.
                final chartHeight = (constraints.maxHeight * 0.22).clamp(
                  150.0,
                  210.0,
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 14,
                          children: [
                            HomeHeader(connected: widget.batonConnected),
                            SessionCard(
                              time: _controller.formattedTime,
                              status: _controller.status,
                              running: _controller.isRunning,
                              onToggle: _controller.toggleSession,
                            ),
                            MotionCard(
                              chartHeight: chartHeight,
                              samples: widget.motionSamples,
                              targetLow: widget.targetLow,
                              targetHigh: widget.targetHigh,
                              isLive:
                                  widget.motionIsLive && widget.batonConnected,
                            ),
                            SetupCard(
                              instrument: _controller.instrument,
                              mode: _controller.mode,
                              onInstrument: _controller.selectInstrument,
                              onMode: _controller.selectMode,
                            ),
                            SlidersCard(
                              volume: _controller.volume,
                              tempo: _controller.tempo,
                              onVolume: _controller.setVolume,
                              onTempo: _controller.setTempo,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
