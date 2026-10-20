import 'package:flutter/material.dart';

import '../core/brand/brand_mark.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Logo variants (all drawn from [BrandMark], so they always match):
///
/// * [AiovyLogoMark] – symbol only: compact headers, launcher icon.
/// * [AiovyWordmark] – horizontal: symbol beside "AIOVY" (+ tagline).
/// * [AiovyLogoStacked] – primary: symbol above "AIOVY" and the tagline.
///
/// Pass `monochrome` (any variant) for a single-colour version on simple or
/// low-colour backgrounds.

/// Brand colour for each tone of the mark.
Color markToneColor(MarkTone tone) => switch (tone) {
      MarkTone.rose => AppColors.primary,
      MarkTone.mauve => AppColors.primaryDark,
      MarkTone.soft => AppColors.brandSoft,
    };

/// The AIOVY symbol.
class AiovyLogoMark extends StatelessWidget {
  const AiovyLogoMark({
    super.key,
    this.size = 32,
    this.showTile = false,
    this.monochrome,
    this.semanticLabel = 'AIOVY logo',
  });

  final double size;

  /// Draws a blush rounded square behind the symbol (app-icon style).
  final bool showTile;

  /// Paints every shape in this one colour.
  final Color? monochrome;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: BrandMarkPainter(showTile: showTile, monochrome: monochrome)),
      ),
    );
  }
}

/// Paints [BrandMark.shapes] scaled to the canvas. Public so tooling can
/// render launcher icons from exactly the same drawing.
class BrandMarkPainter extends CustomPainter {
  BrandMarkPainter({this.showTile = false, this.monochrome, this.tileColor = AppColors.blush, this.inset = 0});

  final bool showTile;
  final Color? monochrome;
  final Color tileColor;

  /// Fraction of the canvas left empty around the symbol (icon safe zones).
  final double inset;

  static Path pathFor(MarkShape s) {
    if (s.isCircle) return Path()..addOval(Rect.fromCircle(center: Offset(s.cx, s.cy), radius: s.r));
    final p = Path();
    parseMarkPath(
      s.d!,
      moveTo: p.moveTo,
      lineTo: p.lineTo,
      cubicTo: p.cubicTo,
      quadTo: p.quadraticBezierTo,
      close: p.close,
    );
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showTile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.225)),
        Paint()..color = tileColor,
      );
    }
    final pad = size.width * inset;
    final s = (size.width - 2 * pad) / BrandMark.canvas;
    canvas
      ..save()
      ..translate(pad, pad)
      ..scale(s, s);
    for (final shape in BrandMark.shapes) {
      canvas.drawPath(
        pathFor(shape),
        Paint()
          ..isAntiAlias = true
          ..color = monochrome ?? markToneColor(shape.tone),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BrandMarkPainter old) =>
      old.showTile != showTile || old.monochrome != monochrome || old.tileColor != tileColor || old.inset != inset;
}

TextStyle _wordStyle(double fontSize, Color color) => AppTextStyles.titleMd.weight(FontWeight.w500).copyWith(
      fontSize: fontSize,
      height: 1,
      letterSpacing: fontSize * 0.2,
      color: color,
    );

TextStyle _taglineStyle(double fontSize, Color color) => AppTextStyles.labelSm.weight(FontWeight.w600).copyWith(
      fontSize: fontSize,
      height: 1.2,
      letterSpacing: fontSize * 0.22,
      color: color,
    );

/// Horizontal logo: symbol beside "AIOVY", with the tagline beneath the
/// name when [showSubLabel] is true. [height] is the symbol's size.
class AiovyWordmark extends StatelessWidget {
  const AiovyWordmark({super.key, this.height = 32, this.showSubLabel = true, this.monochrome});

  final double height;
  final bool showSubLabel;
  final Color? monochrome;

  @override
  Widget build(BuildContext context) {
    final color = monochrome ?? AppColors.primaryDark;
    final scale = height / 32;
    // The tagline is decorative here; never let text scaling blow up a header.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Semantics(
        label: 'AIOVY, Maternal Care Intelligence',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AiovyLogoMark(size: height, monochrome: monochrome),
            SizedBox(width: 8 * scale),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.appName, style: _wordStyle(17 * scale, color)),
                if (showSubLabel) ...[
                  SizedBox(height: 3 * scale),
                  Text(AppStrings.wordmarkSub, style: _taglineStyle(6 * scale, color)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary logo: the symbol centred above "AIOVY" and the tagline.
class AiovyLogoStacked extends StatelessWidget {
  const AiovyLogoStacked({super.key, this.symbolSize = 112, this.monochrome});

  final double symbolSize;
  final Color? monochrome;

  @override
  Widget build(BuildContext context) {
    final color = monochrome ?? AppColors.primaryDark;
    final scale = symbolSize / 112;
    return Semantics(
      label: 'AIOVY, Maternal Care Intelligence',
      header: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AiovyLogoMark(size: symbolSize, monochrome: monochrome),
          SizedBox(height: 18 * scale),
          // Extra right padding balances the trailing letter-spacing so the
          // word looks centred.
          Padding(
            padding: EdgeInsets.only(left: 34 * scale * 0.2),
            child: Text(AppStrings.appName, style: _wordStyle(34 * scale, color)),
          ),
          SizedBox(height: 10 * scale),
          Text(AppStrings.wordmarkSub, style: _taglineStyle(10 * scale, color), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
