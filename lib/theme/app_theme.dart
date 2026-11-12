import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ground = Color(0xFFF3EEFF);
  static const ink = Color(0xFF1E1640);
  static const muted = Color(0xFF6B6390);
  static const grape = Color(0xFF5B3DF5);
  static const grapeSoft = Color(0xFFECE6FF);
  static const mint = Color(0xFF19B394);
  static const mintSoft = Color(0xFFDDF7EF);
  static const mintInk = Color(0xFF0B6E57);

  static const cardShadow = [
    BoxShadow(color: Color(0x145B3DF5), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static final light = ThemeData(
    useMaterial3: true,
    platform: TargetPlatform.iOS,
    colorScheme: ColorScheme.fromSeed(
      seedColor: grape,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: ground,
    fontFamily: 'Nunito',
    splashFactory: NoSplash.splashFactory,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );

  static TextStyle display(double size, {Color color = ink}) => TextStyle(
    fontFamily: 'Fredoka',
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color,
    height: 1.1,
  );

  static TextStyle body(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w800,
  }) => TextStyle(
    fontFamily: 'Nunito',
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}
