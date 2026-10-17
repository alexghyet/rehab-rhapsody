import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/surface_card.dart';

class SlidersCard extends StatelessWidget {
  const SlidersCard({
    super.key,
    required this.volume,
    required this.tempo,
    required this.onVolume,
    required this.onTempo,
  });

  final double volume;
  final double tempo;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onTempo;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        spacing: 8,
        children: [
          BubbleSlider(
            label: 'Volume',
            valueText: '${volume.round()}%',
            semanticFormatter: (value) => '${value.round()}%',
            icon: Icons.volume_up_rounded,
            iconBackground: AppTheme.grapeSoft,
            iconColor: AppTheme.grape,
            value: volume,
            min: 0,
            max: 100,
            onChanged: onVolume,
          ),
          BubbleSlider(
            label: 'Tempo',
            valueText: '${tempo.round()} BPM',
            semanticFormatter: (value) => '${value.round()} BPM',
            icon: Icons.speed_rounded,
            iconBackground: AppTheme.peach,
            iconColor: AppTheme.peachInk,
            value: tempo,
            min: 40,
            max: 140,
            onChanged: onTempo,
          ),
        ],
      ),
    );
  }
}

class BubbleSlider extends StatelessWidget {
  const BubbleSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.semanticFormatter,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final SemanticFormatterCallback semanticFormatter;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 15, color: iconColor),
                  ),
                  Flexible(child: Text(label, style: AppTheme.display(17))),
                ],
              ),
              Text(valueText, style: AppTheme.body(14, color: AppTheme.muted)),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 14,
            activeTrackColor: AppTheme.grape,
            inactiveTrackColor: AppTheme.grapeSoft,
            thumbShape: const _RingThumb(),
            trackShape: const _FullWidthTrack(),
            overlayColor: const Color(0x1F5B3DF5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Slider(
              label: label,
              value: value.clamp(min, max),
              min: min,
              max: max,
              semanticFormatterCallback: semanticFormatter,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _FullWidthTrack extends RoundedRectSliderTrackShape {
  const _FullWidthTrack();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = sliderTheme.trackHeight ?? 14;
    final top = offset.dy + (parentBox.size.height - height) / 2;
    return Rect.fromLTWH(
      offset.dx + _RingThumb.radius,
      top,
      (parentBox.size.width - 2 * _RingThumb.radius).clamp(
        0.0,
        double.infinity,
      ),
      height,
    );
  }
}

class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  static const radius = 15.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final color = sliderTheme.activeTrackColor ?? AppTheme.grape;
    canvas.drawCircle(
      center + const Offset(0, 3),
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(center, radius - 7, Paint()..color = Colors.white);
  }
}
