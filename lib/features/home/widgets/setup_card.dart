import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/surface_card.dart';
import '../home_options.dart';

class SetupCard extends StatelessWidget {
  const SetupCard({
    super.key,
    required this.instrument,
    required this.mode,
    required this.onInstrument,
    required this.onMode,
  });

  final Instrument instrument;
  final PlayMode mode;
  final ValueChanged<Instrument> onInstrument;
  final ValueChanged<PlayMode> onMode;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text('Instrument', style: AppTheme.display(18)),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
              final minimumTileWidth = (64 * textScale).clamp(70.0, 192.0);
              final columns = constraints.maxWidth >= minimumTileWidth * 4 + 24
                  ? 4
                  : constraints.maxWidth >= 148
                  ? 2
                  : 1;
              final tileWidth =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in Instrument.values)
                    SizedBox(
                      width: tileWidth,
                      child: _InstrumentTile(
                        instrument: option,
                        selected: option == instrument,
                        onTap: () => onInstrument(option),
                      ),
                    ),
                ],
              );
            },
          ),
          Text('Mode of play', style: AppTheme.display(18)),
          _ModeSwitcher(mode: mode, onChanged: onMode),
        ],
      ),
    );
  }
}

class _InstrumentTile extends StatelessWidget {
  const _InstrumentTile({
    required this.instrument,
    required this.selected,
    required this.onTap,
  });

  final Instrument instrument;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Semantics(
      button: true,
      selected: selected,
      label: instrument.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppTheme.grapeSoft : AppTheme.tile,
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppTheme.grape : Colors.transparent,
              width: 3,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 66),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 6,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: instrument.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        instrument.icon,
                        size: 18,
                        color: instrument.ink,
                      ),
                    ),
                    Text(
                      instrument.label,
                      textAlign: TextAlign.center,
                      style: AppTheme.body(13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});

  final PlayMode mode;
  final ValueChanged<PlayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final vertical = constraints.maxWidth < 72 * textScale * 3 + 16;
        final options = [
          for (final option in PlayMode.values)
            _ModeOption(
              mode: option,
              selected: option == mode,
              onTap: () => onChanged(option),
            ),
        ];

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.ground,
            borderRadius: BorderRadius.circular(vertical ? 28 : 999),
          ),
          child: vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: options,
                )
              : Row(
                  spacing: 4,
                  children: [
                    for (final option in options) Expanded(child: option),
                  ],
                ),
        );
      },
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final PlayMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      selected: selected,
      label: mode.label,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0x00FFFFFF),
          borderRadius: radius,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x2E5B3DF5),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Center(
                  child: Text(
                    mode.label,
                    textAlign: TextAlign.center,
                    style: AppTheme.body(
                      14,
                      color: selected ? AppTheme.grape : AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
