import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography scale (Inter).
///
/// Every style is created through [GoogleFonts.inter] so the font file for
/// its *own* weight is loaded. Setting only a family name and then changing
/// `fontWeight` makes the engine synthesize bold from the regular file, so
/// use [AppTextStyleX.weight] rather than `copyWith(fontWeight: ...)`.
///
/// Without network access (or before the font has downloaded) text falls
/// back to the platform sans-serif.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _inter(
    double size,
    double lineHeight,
    FontWeight weight, {
    double? letterSpacing,
    Color color = AppColors.onSurface,
  }) =>
      GoogleFonts.inter(
        textStyle: TextStyle(
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          color: color,
        ),
      );

  static final TextStyle displayLg = _inter(32, 38, FontWeight.w700, letterSpacing: -0.6);
  static final TextStyle headlineLg = _inter(28, 34, FontWeight.w700, letterSpacing: -0.5);
  static final TextStyle headlineMd = _inter(22, 28, FontWeight.w600, letterSpacing: -0.3);
  static final TextStyle headlineSm = _inter(19, 24, FontWeight.w600, letterSpacing: -0.2);
  static final TextStyle titleMd = _inter(17, 22, FontWeight.w600, letterSpacing: -0.1);
  static final TextStyle bodyLg = _inter(17, 25, FontWeight.w400);

  /// Default reading size: 16 px for legibility in the field.
  static final TextStyle bodyMd = _inter(16, 23, FontWeight.w400);
  static final TextStyle bodySm = _inter(14, 20, FontWeight.w400);
  static final TextStyle labelLg = _inter(15, 20, FontWeight.w600);
  static final TextStyle labelMd = _inter(14, 19, FontWeight.w500);

  /// 12 px is the legibility floor; nothing in the app is smaller.
  static final TextStyle labelSm = _inter(12, 16, FontWeight.w600);

  static final TextStyle overline = _inter(
    12,
    16,
    FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.onSurfaceVariant,
  );

  /// Large numerals: indicator inputs, counts, probabilities.
  static final TextStyle metric = _inter(
    24,
    28,
    FontWeight.w600,
    letterSpacing: -0.3,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

extension AppTextStyleX on TextStyle {
  /// The same style at another Inter weight, using that weight's real font.
  TextStyle weight(FontWeight w) => GoogleFonts.inter(textStyle: copyWith(fontWeight: w));

  /// Fixed-width digits so columns of numbers line up and don't jitter.
  TextStyle get tabular => copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
