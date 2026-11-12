import 'package:flutter/services.dart';

/// Use the bundled fonts so layout tests measure the same text as the app.
Future<void> loadTestFonts() async {
  final display = FontLoader('Fredoka')
    ..addFont(rootBundle.load('assets/fonts/Fredoka-600.ttf'));
  final body = FontLoader('Nunito')
    ..addFont(rootBundle.load('assets/fonts/Nunito-700.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Nunito-800.ttf'));
  await Future.wait([display.load(), body.load()]);
}
