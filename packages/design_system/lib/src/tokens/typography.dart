import 'package:flutter/material.dart';

import 'colors.dart';

/// Typography — bundled Inter for UI, Noto Sans Kannada for brand accents.
/// Fonts ship as package assets (no runtime fetching, works offline/tests).
abstract final class ZTypography {
  static const String _ui = 'Inter';
  static const String _kannada = 'NotoSansKannada';

  static TextStyle _base(
    double fontSize,
    double lineHeight,
    FontWeight weight, {
    Color? color,
    double? letterSpacing,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: _ui,
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontWeight: weight,
      color: color ?? ZColors.textPrimary,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : const [],
    );
  }

  // Tracking per Gemini UI spec: −0.5 / −0.3 / −0.1 / 0 / +0.1 / +0.4.
  static TextStyle get display => _base(28, 34, FontWeight.w700, letterSpacing: -0.5);
  static TextStyle get titleLg => _base(22, 28, FontWeight.w700, letterSpacing: -0.3);
  static TextStyle get titleMd => _base(17, 24, FontWeight.w600, letterSpacing: -0.1);
  static TextStyle get body => _base(15, 22, FontWeight.w400);
  static TextStyle get bodyStrong => _base(15, 22, FontWeight.w600);
  static TextStyle get caption => _base(13, 18, FontWeight.w400, letterSpacing: 0.1);
  static TextStyle get captionStrong => _base(13, 18, FontWeight.w600, letterSpacing: 0.1);
  static TextStyle get overline => _base(
        11,
        16,
        FontWeight.w600,
        color: ZColors.textSecondary,
        letterSpacing: 0.4,
      );

  /// Fares, ETAs, plates, PINs — tabular figures so live numbers never jitter.
  static TextStyle get numeric => _base(15, 22, FontWeight.w600, tabular: true);
  static TextStyle get numericLg => _base(22, 28, FontWeight.w700, tabular: true);

  /// Kannada companion for brand moments (section accents, splash).
  static TextStyle kannada({double fontSize = 13, Color? color, FontWeight weight = FontWeight.w400}) {
    return TextStyle(
      fontFamily: _kannada,
      fontSize: fontSize,
      height: 18 / fontSize,
      fontWeight: weight,
      color: color ?? ZColors.textSecondary,
    );
  }
}
