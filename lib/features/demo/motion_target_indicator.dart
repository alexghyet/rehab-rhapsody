import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A narrow companion to the note highway, visible while following the music.
class MotionTargetIndicator extends StatelessWidget {
  const MotionTargetIndicator({
    super.key,
    required this.targetLow,
    required this.targetHigh,
    required this.isLive,
    this.currentLevel,
  });

  final double targetLow;
  final double targetHigh;
  final double? currentLevel;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final level = isLive && currentLevel != null && currentLevel!.isFinite
        ? currentLevel!.clamp(0.0, 1.0)
        : null;
    final inTarget = level != null && level >= targetLow && level <= targetHigh;
    final status = level == null
        ? 'Waiting for baton'
        : inTarget
        ? 'In target'
        : level < targetLow
        ? 'Higher'
        : 'Lower';
    return Tooltip(
      message: 'Hold in the zone',
      child: Semantics(
        label: 'Live movement target. $status.',
        value: level == null
            ? 'Position unavailable'
            : '${(level * 100).round()} percent',
        image: true,
        child: CustomPaint(
          painter: _TargetGaugePainter(
            low: targetLow,
            high: targetHigh,
            level: level,
            inTarget: inTarget,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TargetGaugePainter extends CustomPainter {
  const _TargetGaugePainter({
    required this.low,
    required this.high,
    required this.level,
    required this.inTarget,
  });

  final double low;
  final double high;
  final double? level;
  final bool inTarget;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    if (size.width <= 0 || size.height <= inset * 2) return;
    final height = size.height - inset * 2;
    double y(double value) => inset + height * (1 - value.clamp(0.0, 1.0));
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, inset, size.width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(track, Paint()..color = AppTheme.grapeSoft);
    canvas.save();
    canvas.clipRRect(track);
    for (final value in [0.25, 0.5, 0.75]) {
      canvas.drawLine(
        Offset(0, y(value)),
        Offset(size.width, y(value)),
        Paint()
          ..color = AppTheme.grape.withValues(alpha: 0.12)
          ..strokeWidth = 1,
      );
    }
    final band = Rect.fromLTRB(0, y(high), size.width, y(low));
    canvas.drawRect(
      band,
      Paint()..color = AppTheme.mint.withValues(alpha: 0.38),
    );
    final border = Paint()
      ..color = AppTheme.mintInk
      ..strokeWidth = 1;
    canvas.drawLine(band.topLeft, band.topRight, border);
    canvas.drawLine(band.bottomLeft, band.bottomRight, border);
    canvas.restore();
    if (level != null) {
      final center = Offset(size.width / 2, y(level!));
      canvas.drawCircle(center, 8, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        5.5,
        Paint()..color = inTarget ? AppTheme.mintInk : AppTheme.grape,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TargetGaugePainter oldDelegate) =>
      low != oldDelegate.low ||
      high != oldDelegate.high ||
      level != oldDelegate.level ||
      inTarget != oldDelegate.inTarget;
}
