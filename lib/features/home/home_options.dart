import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum Instrument {
  piano('Piano', Icons.piano, AppTheme.peach, AppTheme.peachInk),
  strings(
    'Strings',
    Icons.music_note_rounded,
    AppTheme.mintSoft,
    AppTheme.mintInk,
  ),
  drums('Drums', Icons.album_rounded, Color(0xFFFFF1C2), Color(0xFF8A5300)),
  flute('Flute', Icons.air_rounded, Color(0xFFE1EEFF), Color(0xFF1D4ED8));

  const Instrument(this.label, this.icon, this.tint, this.ink);

  final String label;
  final IconData icon;
  final Color tint;
  final Color ink;
}

enum PlayMode {
  free('Free play'),
  guided('Guided'),
  rhythm('Rhythm');

  const PlayMode(this.label);

  final String label;
}
