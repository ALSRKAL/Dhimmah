import 'package:flutter/material.dart';

/// Type scale for Dhimmah.
///
/// One family — IBM Plex Sans Arabic — carries both scripts, which keeps the
/// Arabic and Latin interfaces visually identical in weight and rhythm. Arabic
/// sits on a taller line box, so [height] is generous throughout.
abstract final class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'IBMPlexSansArabic';

  /// Lining, tabular figures keep money columns aligned in lists. The font
  /// falls back gracefully when a feature is unavailable.
  static const List<FontFeature> moneyFeatures = <FontFeature>[
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle h(double size, FontWeight weight, {double? height, Color? color}) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height ?? 1.35,
        letterSpacing: 0,
        color: color ?? primary,
      );
    }

    return TextTheme(
      displayLarge: h(40, FontWeight.w700, height: 1.2),
      displayMedium: h(34, FontWeight.w700, height: 1.22),
      displaySmall: h(30, FontWeight.w700, height: 1.25),
      headlineLarge: h(26, FontWeight.w700, height: 1.28),
      headlineMedium: h(23, FontWeight.w700, height: 1.3),
      headlineSmall: h(20, FontWeight.w600, height: 1.32),
      titleLarge: h(19, FontWeight.w600, height: 1.36),
      titleMedium: h(17, FontWeight.w600, height: 1.38),
      titleSmall: h(15, FontWeight.w600, height: 1.4),
      bodyLarge: h(16, FontWeight.w400, height: 1.5),
      bodyMedium: h(15, FontWeight.w400, height: 1.5),
      bodySmall: h(13.5, FontWeight.w400, height: 1.5, color: secondary),
      labelLarge: h(15, FontWeight.w600, height: 1.3),
      labelMedium: h(13, FontWeight.w500, height: 1.3),
      labelSmall: h(12, FontWeight.w500, height: 1.3, color: secondary),
    );
  }
}
