import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class FlutterFlowTheme {
  static FlutterFlowTheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? DarkModeTheme()
        : LightModeTheme();
  }

  Color get primary;
  Color get secondary;
  Color get tertiary;
  Color get alternate;
  Color get primaryText;
  Color get secondaryText;
  Color get primaryBackground;
  Color get secondaryBackground;
  Color get accent1;
  Color get accent2;
  Color get accent3;
  Color get accent4;
  Color get success;
  Color get warning;
  Color get error;
  Color get info;

  String get displayLargeFamily => typography.displayLargeFamily;
  TextStyle get displayLarge => typography.displayLarge;
  String get displayMediumFamily => typography.displayMediumFamily;
  TextStyle get displayMedium => typography.displayMedium;
  String get displaySmallFamily => typography.displaySmallFamily;
  TextStyle get displaySmall => typography.displaySmall;
  String get headlineLargeFamily => typography.headlineLargeFamily;
  TextStyle get headlineLarge => typography.headlineLarge;
  String get headlineMediumFamily => typography.headlineMediumFamily;
  TextStyle get headlineMedium => typography.headlineMedium;
  String get headlineSmallFamily => typography.headlineSmallFamily;
  TextStyle get headlineSmall => typography.headlineSmall;
  String get titleLargeFamily => typography.titleLargeFamily;
  TextStyle get titleLarge => typography.titleLarge;
  String get titleMediumFamily => typography.titleMediumFamily;
  TextStyle get titleMedium => typography.titleMedium;
  String get titleSmallFamily => typography.titleSmallFamily;
  TextStyle get titleSmall => typography.titleSmall;
  String get labelLargeFamily => typography.labelLargeFamily;
  TextStyle get labelLarge => typography.labelLarge;
  String get labelMediumFamily => typography.labelMediumFamily;
  TextStyle get labelMedium => typography.labelMedium;
  String get labelSmallFamily => typography.labelSmallFamily;
  TextStyle get labelSmall => typography.labelSmall;
  String get bodyLargeFamily => typography.bodyLargeFamily;
  TextStyle get bodyLarge => typography.bodyLarge;
  String get bodyMediumFamily => typography.bodyMediumFamily;
  TextStyle get bodyMedium => typography.bodyMedium;
  String get bodySmallFamily => typography.bodySmallFamily;
  TextStyle get bodySmall => typography.bodySmall;

  Typography get typography => ThemeTypography(this);
}

class LightModeTheme extends FlutterFlowTheme {
  @override
  Color get primary => const Color(0xFF4B39EF);
  @override
  Color get secondary => const Color(0xFF39D2C0);
  @override
  Color get tertiary => const Color(0xFFEE8B60);
  @override
  Color get alternate => const Color(0xFFE0E3E7);
  @override
  Color get primaryText => const Color(0xFF14181B);
  @override
  Color get secondaryText => const Color(0xFF57636C);
  @override
  Color get primaryBackground => const Color(0xFFF1F4F8);
  @override
  Color get secondaryBackground => const Color(0xFFFFFFFF);
  @override
  Color get accent1 => const Color(0x4C4B39EF);
  @override
  Color get accent2 => const Color(0x4D39D2C0);
  @override
  Color get accent3 => const Color(0x4DEE8B60);
  @override
  Color get accent4 => const Color(0xCCFFFFFF);
  @override
  Color get success => const Color(0xFF249689);
  @override
  Color get warning => const Color(0xFFF9CF58);
  @override
  Color get error => const Color(0xFFFF5963);
  @override
  Color get info => const Color(0xFFFFFFFF);
}

class DarkModeTheme extends FlutterFlowTheme {
  @override
  Color get primary => const Color(0xFF4B39EF);
  @override
  Color get secondary => const Color(0xFF39D2C0);
  @override
  Color get tertiary => const Color(0xFFEE8B60);
  @override
  Color get alternate => const Color(0xFF262D34);
  @override
  Color get primaryText => const Color(0xFFFFFFFF);
  @override
  Color get secondaryText => const Color(0xFF95A1AC);
  @override
  Color get primaryBackground => const Color(0xFF1D2428);
  @override
  Color get secondaryBackground => const Color(0xFF14181B);
  @override
  Color get accent1 => const Color(0x4C4B39EF);
  @override
  Color get accent2 => const Color(0x4D39D2C0);
  @override
  Color get accent3 => const Color(0x4DEE8B60);
  @override
  Color get accent4 => const Color(0xB2262D34);
  @override
  Color get success => const Color(0xFF249689);
  @override
  Color get warning => const Color(0xFFF9CF58);
  @override
  Color get error => const Color(0xFFFF5963);
  @override
  Color get info => const Color(0xFFFFFFFF);
}

abstract class Typography {
  String get displayLargeFamily;
  TextStyle get displayLarge;
  String get displayMediumFamily;
  TextStyle get displayMedium;
  String get displaySmallFamily;
  TextStyle get displaySmall;
  String get headlineLargeFamily;
  TextStyle get headlineLarge;
  String get headlineMediumFamily;
  TextStyle get headlineMedium;
  String get headlineSmallFamily;
  TextStyle get headlineSmall;
  String get titleLargeFamily;
  TextStyle get titleLarge;
  String get titleMediumFamily;
  TextStyle get titleMedium;
  String get titleSmallFamily;
  TextStyle get titleSmall;
  String get labelLargeFamily;
  TextStyle get labelLarge;
  String get labelMediumFamily;
  TextStyle get labelMedium;
  String get labelSmallFamily;
  TextStyle get labelSmall;
  String get bodyLargeFamily;
  TextStyle get bodyLarge;
  String get bodyMediumFamily;
  TextStyle get bodyMedium;
  String get bodySmallFamily;
  TextStyle get bodySmall;
}

class ThemeTypography extends Typography {
  ThemeTypography(this.theme);

  final FlutterFlowTheme theme;

  @override
  String get displayLargeFamily => 'Inter Tight';
  @override
  TextStyle get displayLarge => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 64.0,
  );
  @override
  String get displayMediumFamily => 'Inter Tight';
  @override
  TextStyle get displayMedium => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 44.0,
  );
  @override
  String get displaySmallFamily => 'Inter Tight';
  @override
  TextStyle get displaySmall => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 36.0,
  );
  @override
  String get headlineLargeFamily => 'Inter Tight';
  @override
  TextStyle get headlineLarge => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 32.0,
  );
  @override
  String get headlineMediumFamily => 'Inter Tight';
  @override
  TextStyle get headlineMedium => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 28.0,
  );
  @override
  String get headlineSmallFamily => 'Inter Tight';
  @override
  TextStyle get headlineSmall => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 24.0,
  );
  @override
  String get titleLargeFamily => 'Inter Tight';
  @override
  TextStyle get titleLarge => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 20.0,
  );
  @override
  String get titleMediumFamily => 'Inter Tight';
  @override
  TextStyle get titleMedium => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 18.0,
  );
  @override
  String get titleSmallFamily => 'Inter Tight';
  @override
  TextStyle get titleSmall => GoogleFonts.interTight(
    color: theme.primaryText,
    fontWeight: FontWeight.w600,
    fontSize: 16.0,
  );
  @override
  String get labelLargeFamily => 'Inter';
  @override
  TextStyle get labelLarge => GoogleFonts.inter(
    color: theme.secondaryText,
    fontWeight: FontWeight.normal,
    fontSize: 16.0,
  );
  @override
  String get labelMediumFamily => 'Inter';
  @override
  TextStyle get labelMedium => GoogleFonts.inter(
    color: theme.secondaryText,
    fontWeight: FontWeight.normal,
    fontSize: 14.0,
  );
  @override
  String get labelSmallFamily => 'Inter';
  @override
  TextStyle get labelSmall => GoogleFonts.inter(
    color: theme.secondaryText,
    fontWeight: FontWeight.normal,
    fontSize: 12.0,
  );
  @override
  String get bodyLargeFamily => 'Inter';
  @override
  TextStyle get bodyLarge => GoogleFonts.inter(
    color: theme.primaryText,
    fontWeight: FontWeight.normal,
    fontSize: 16.0,
  );
  @override
  String get bodyMediumFamily => 'Inter';
  @override
  TextStyle get bodyMedium => GoogleFonts.inter(
    color: theme.primaryText,
    fontWeight: FontWeight.normal,
    fontSize: 14.0,
  );
  @override
  String get bodySmallFamily => 'Inter';
  @override
  TextStyle get bodySmall => GoogleFonts.inter(
    color: theme.primaryText,
    fontWeight: FontWeight.normal,
    fontSize: 12.0,
  );
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    FontStyle? fontStyle,
    bool useGoogleFonts = false,
    TextDecoration? decoration,
    double? lineHeight,
    List<Shadow>? shadows,
    String? package,
  }) {
    if (useGoogleFonts && fontFamily != null) {
      font = GoogleFonts.getFont(
        fontFamily,
        fontWeight: fontWeight ?? this.fontWeight,
        fontStyle: fontStyle ?? this.fontStyle,
      );
    }

    return font != null
        ? font.copyWith(
            color: color ?? this.color,
            fontSize: fontSize ?? this.fontSize,
            letterSpacing: letterSpacing ?? this.letterSpacing,
            fontWeight: fontWeight ?? this.fontWeight,
            fontStyle: fontStyle ?? this.fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          )
        : copyWith(
            fontFamily: fontFamily,
            package: package,
            color: color,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: decoration,
            height: lineHeight,
            shadows: shadows,
          );
  }
}
