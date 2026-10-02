import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rehab_rhapsody/main.dart';

void main() {
  setUpAll(() {
    // Tests have no network access, so don't try to download fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Home page renders', (WidgetTester tester) async {
    // The page's Column doesn't scroll, so it needs more height than the
    // default 800x600 test surface. It's also wider than a phone because the
    // test font renders every glyph as a full em-square, which makes the
    // 44px timer text much wider than it is with the real font.
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Instrument'), findsOneWidget);
    expect(find.text('Mode of Play'), findsOneWidget);
    expect(find.text('Start Session'), findsOneWidget);
  });
}
