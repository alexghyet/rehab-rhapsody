import 'package:flutter/material.dart';

enum Instrument {
  piano('Piano', Icons.piano),
  strings('Strings', Icons.music_note_rounded),
  drums('Drums', Icons.album_rounded),
  flute('Flute', Icons.air_rounded);

  const Instrument(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum PlayMode {
  song('Songs'),
  free('Free play'),
  guided('Guided'),
  rhythm('Rhythm');

  const PlayMode(this.label);

  final String label;
}
