import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(
              'Ready to conduct?',
              style: AppTheme.body(
                14,
                color: AppTheme.muted,
                weight: FontWeight.w700,
              ),
            ),
            Semantics(
              header: true,
              child: Text('Rehab Rhapsody', style: AppTheme.display(27)),
            ),
          ],
        ),
        Semantics(
          label: connected ? 'Baton connected' : 'Baton not connected',
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x245B3DF5),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: connected ? AppTheme.mint : AppTheme.muted,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: connected
                            ? AppTheme.mintSoft
                            : AppTheme.grapeSoft,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    connected ? 'Baton linked' : 'Baton offline',
                    style: AppTheme.body(14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
