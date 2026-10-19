import 'package:flutter/material.dart';

/// AIOVY colour tokens ("clinical calm").
///
/// Surfaces are warm neutrals separated by hairline borders rather than
/// shadows. Rose ([primary]) is reserved for actions, focus, selection and
/// links; risk colours are semantic only and always paired with an icon and
/// text. Contrast ratios are against white unless noted.
///
/// Keep every colour in this file so the palette can be tuned in one place.
class AppColors {
  AppColors._();

  // ── Surfaces ────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF6F4F3); // page canvas
  static const Color surfaceLowest = Color(0xFFFFFFFF); // cards, sheets
  static const Color surfaceLow = Color(0xFFF2EFEE); // input wells, inner tiles
  static const Color surfaceContainer = Color(0xFFECE8E7); // tracks, neutral pills
  static const Color surfaceHigh = Color(0xFFE5E0DF);
  static const Color surfaceHighest = Color(0xFFDDD7D6);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF1F1A1C); // 17.2:1
  static const Color onSurfaceVariant = Color(0xFF5C4E54); // 7.9:1

  /// Meta text and placeholders: 5.4:1 on white, 4.9:1 on [surface].
  static const Color outline = Color(0xFF77666D);
  static const Color outlineVariant = Color(0xFFDCD2D5);

  /// Card and group borders (decorative; the card fill carries the boundary).
  static const Color border = Color(0xFFE6DFE1);

  /// Input boundary: 3.7:1 on white, 3.3:1 on [surfaceLow] (WCAG 1.4.11).
  static const Color fieldBorder = Color(0xFF927F87);
  static const Color fieldBorderFocus = primary;
  static const Color divider = Color(0xFFEDE7E9);

  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFA32F5E); // 6.7:1
  static const Color primaryPressed = Color(0xFF87224C);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Selected-state tint (nav indicator, selected chips, focus wells).
  static const Color primarySoft = Color(0xFFFAEEF2);
  static const Color primaryContainer = Color(0xFFC34877);
  static const Color primaryFixed = Color(0xFFFFD9E2);
  static const Color primaryFixedDim = Color(0xFFFFB1C7);
  static const Color onPrimaryFixed = Color(0xFF3E001D);
  static const Color onPrimaryFixedVariant = Color(0xFF871749);
  static const Color brandPink = Color(0xFFC84C7B); // logo stroke
  static const Color brandInk = Color(0xFF2D1924); // logo ink / dark plum
  static const Color brandTint = Color(0xFFFDF2F5); // logo tile

  static const Color secondary = Color(0xFF645C5F);
  static const Color secondaryContainer = Color(0xFFEAE4E6);
  static const Color onSecondaryContainer = Color(0xFF52484C);
  static const Color secondaryFixed = Color(0xFFEDE6E8);

  static const Color tertiary = Color(0xFF6F5561);
  static const Color tertiaryContainer = Color(0xFF896D7A);
  static const Color tertiaryFixed = Color(0xFFF3E6EC);
  static const Color onTertiaryFixed = Color(0xFF291520);

  static const Color error = Color(0xFFB3261E); // 6.5:1
  static const Color errorTint = Color(0xFFFCEEEC);

  /// Neutral information banner (prefilled values, prototype notices).
  static const Color infoTint = Color(0xFFF0EDF3);
  static const Color infoInk = Color(0xFF4A4458);

  // ── Risk (semantic only – do not use decoratively) ──────────────────────
  static const Color riskLow = Color(0xFF1D7754); // 5.5:1
  static const Color riskLowTint = Color(0xFFEAF5EF);
  static const Color riskModerate = Color(0xFFB4690E); // graphics only (4.2:1)

  /// Text version of moderate: 5.7:1 on its tint, 6.2:1 on white.
  static const Color riskModerateText = Color(0xFF8F520A);
  static const Color riskModerateTint = Color(0xFFFCF4E4);

  /// A true red, deliberately a different hue from the rose [primary] so a
  /// primary button never reads as "high risk". 6.6:1 on white.
  static const Color riskHigh = Color(0xFFB42318);
  static const Color riskHighTint = Color(0xFFFDEEEC);

  // ── SHAP chart ──────────────────────────────────────────────────────────
  /// Bars that support the predicted class (or, for demo output, push toward
  /// higher risk).
  static const Color shapPositive = primary;

  /// Bars that count against it. Neutral slate so the two directions differ
  /// in hue and lightness, not only in hue.
  static const Color shapNegative = Color(0xFF6E7F8D); // 4.1:1
}
