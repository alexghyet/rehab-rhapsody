import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/decorative_bubble.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.time,
    required this.status,
    required this.running,
    required this.onToggle,
  });

  final String time;
  final String status;
  final bool running;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    const soft = Color(0xE6FFFFFF);
    final radius = BorderRadius.circular(32);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.grape,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D5B3DF5),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned(
              top: -56,
              right: 64,
              child: DecorativeBubble(size: 140, color: Color(0x1AFFFFFF)),
            ),
            const Positioned(
              bottom: -26,
              left: 110,
              child: DecorativeBubble(size: 70, color: Color(0x1FFFFFFF)),
            ),
            const Positioned(
              top: 16,
              left: 190,
              child: DecorativeBubble(size: 22, color: Color(0x33FFFFFF)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        'Session time',
                        style: AppTheme.body(14, color: soft),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          time,
                          style: AppTheme.display(44, color: Colors.white)
                              .copyWith(
                                letterSpacing: 0.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                      Text(
                        status,
                        style: AppTheme.body(
                          13,
                          color: soft,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                  final button = _PlayButton(running: running, onTap: onToggle);
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  if (constraints.maxWidth < 280 || scale > 1.3) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        details,
                        Align(child: button),
                      ],
                    );
                  }
                  return Row(
                    spacing: 12,
                    children: [
                      Expanded(child: details),
                      button,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: running ? 'Pause session' : 'Start session',
      onTap: onTap,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0x2EFFFFFF),
          shape: BoxShape.circle,
        ),
        child: IconButton.filled(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.grape,
            fixedSize: const Size.square(80),
          ),
          iconSize: 42,
          icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
      ),
    );
  }
}
