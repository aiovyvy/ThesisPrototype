import 'package:flutter/material.dart';

/// AIOVY colour tokens ("modern clinical warmth").
///
/// Warm ivory canvas, white surfaces separated by hairline borders rather
/// than shadows. Muted rose ([primary]) is reserved for actions, focus,
/// selection and links; sage marks completed input; risk colours are
/// semantic only and always paired with an icon and text. Contrast ratios
/// are against white unless noted (computed, WCAG 2.1).
///
/// Keep every colour in this file so the palette can be tuned in one place.
class AppColors {
  AppColors._();

  // ── Surfaces ────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFAF8F6); // warm ivory canvas
  static const Color surfaceLowest = Color(0xFFFFFFFF); // cards, sheets
  static const Color surfaceLow = Color(0xFFF3EFEC); // input wells, inner tiles
  static const Color surfaceContainer = Color(0xFFEDE8E5); // tracks, neutral pills
  static const Color surfaceHigh = Color(0xFFE6E0DD);
  static const Color surfaceHighest = Color(0xFFDDD6D3);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF302B30); // warm charcoal, 13.1:1 on canvas
  static const Color onSurfaceVariant = Color(0xFF5E5660); // 7.1:1

  /// Meta text and placeholders: 5.2:1 on white, 4.9:1 on [surface], 4.6:1 on [surfaceLow].
  static const Color outline = Color(0xFF736A72);
  static const Color outlineVariant = Color(0xFFDDD5D6);

  /// Card and group borders (decorative; the card fill carries the boundary).
  static const Color border = Color(0xFFEAE4E1);

  /// Input boundary: 3.8:1 on white, 3.3:1 on [surfaceLow] (WCAG 1.4.11).
  static const Color fieldBorder = Color(0xFF8C8189);
  static const Color fieldBorderFocus = primary;
  static const Color divider = Color(0xFFEFEAE7);

  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFA65B76); // muted rose; white text on it 4.8:1
  static const Color primaryPressed = Color(0xFF82445F);

  /// Rose text on rose tints (selected nav label, selected chips): 6.2:1 on
  /// [primarySoft], where [primary] would only reach 4.1:1.
  static const Color primaryDark = Color(0xFF82445F);

  /// Muted sage: the supporting accent. Used only for "entered / valid"
  /// states, so input completeness is never shown in a risk colour.
  /// 3.3:1 on white (graphics); use [sageText] for text.
  static const Color sage = Color(0xFF789486);
  static const Color sageText = Color(0xFF5E7A6C); // 4.7:1
  static const Color sageTint = Color(0xFFEEF2EF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Selected-state tint (nav indicator, selected chips, focus wells).
  static const Color primarySoft = Color(0xFFF5ECEF);
  static const Color primaryContainer = Color(0xFFB97A91);
  static const Color primaryFixed = Color(0xFFEFDCE3);
  static const Color primaryFixedDim = Color(0xFFDDBAC7);
  static const Color onPrimaryFixed = Color(0xFF3E001D);
  static const Color onPrimaryFixedVariant = Color(0xFF82445F);
  static const Color brandPink = Color(0xFFA65B76); // logo stroke

  /// Blush: icon tiles and quiet brand backgrounds (decorative only).
  static const Color blush = Color(0xFFF8DDE3);

  /// Soft rose in the symbol (leaf, baby's wrap). Decorative: 2.2:1.
  static const Color brandSoft = Color(0xFFD29AAE);
  static const Color brandInk = Color(0xFF302B30); // logo ink / dark plum
  static const Color brandTint = Color(0xFFF7EFF2); // logo tile

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
