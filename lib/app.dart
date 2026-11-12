import 'package:flutter/material.dart';

import 'features/demo/demo_controller.dart';
import 'features/demo/demo_screen.dart';
import 'theme/app_theme.dart';

class RehabRhapsodyApp extends StatelessWidget {
  const RehabRhapsodyApp({super.key, this.demoController});
  final DemoController? demoController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rehab Rhapsody',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: DemoScreen(controller: demoController),
    );
  }
}
