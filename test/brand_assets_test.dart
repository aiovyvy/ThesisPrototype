// Brand tooling. Skipped unless asked for:
//
//   Preview sheet (for design review):
//     flutter test test/brand_assets_test.dart --dart-define=BRAND_PREVIEW=<folder>
//
//   Regenerate the committed brand assets (SVG, launcher and web icons,
//   Android launch image) from lib/core/brand/brand_mark.dart:
//     flutter test test/brand_assets_test.dart --dart-define=BRAND_EXPORT=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aiovy/core/brand/brand_mark.dart';
import 'package:aiovy/core/theme/app_colors.dart';
import 'package:aiovy/widgets/aiovy_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/test_app.dart';

const _preview = String.fromEnvironment('BRAND_PREVIEW');
final _key = GlobalKey();

Future<void> _capture(WidgetTester tester, Widget child, Size size, String path, {double dpr = 1}) async {
  setScreen(tester, size, dpr: dpr);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: _key, child: child),
    ),
  );
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pumpAndSettle();
  final ro = tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await ro.toImage(pixelRatio: dpr);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _sheet() {
  Widget label(String t) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(t, style: const TextStyle(fontFamily: 'Roboto', fontSize: 11, color: AppColors.outline)),
      );
  Widget cell(Widget w, String t, {Color bg = AppColors.surface}) => Container(
        color: bg,
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [w, label(t)]),
      );
  return Material(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          cell(const AiovyLogoMark(size: 240), 'symbol 240'),
          cell(const AiovyLogoMark(size: 120, showTile: true), 'tile 120'),
          for (final s in [64.0, 48.0, 32.0, 24.0, 16.0]) cell(AiovyLogoMark(size: s), '${s.toInt()}'),
          cell(const AiovyLogoMark(size: 96, monochrome: AppColors.primaryDark), 'mono'),
          cell(const AiovyLogoMark(size: 96, monochrome: Colors.white), 'mono on mauve', bg: AppColors.primaryDark),
          cell(const AiovyWordmark(height: 40), 'horizontal'),
          cell(const AiovyWordmark(height: 30, showSubLabel: false), 'horizontal, no tagline'),
          cell(const AiovyLogoStacked(symbolSize: 112), 'primary (stacked)'),
        ],
      ),
    ),
  );
}

const _export = bool.fromEnvironment('BRAND_EXPORT');

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The symbol as SVG elements, translated/scaled into a larger drawing.
String _svgShapes({Color? mono, double x = 0, double y = 0, double scale = 1}) {
  final b = StringBuffer('  <g transform="translate($x $y) scale($scale)">\n');
  for (final s in BrandMark.shapes) {
    final fill = _hex(mono ?? markToneColor(s.tone));
    b.writeln(
      s.isCircle
          ? '    <circle cx="${s.cx}" cy="${s.cy}" r="${s.r}" fill="$fill"/>'
          : '    <path d="${s.d}" fill="$fill"/>',
    );
  }
  return '$b  </g>\n';
}

String _svg(double w, double h, String body, String title) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="$w" height="$h" role="img">\n'
    '  <title>$title</title>\n'
    '  <!-- Generated from lib/core/brand/brand_mark.dart by test/brand_assets_test.dart. Do not edit. -->\n'
    '$body</svg>\n';

String _text(double x, double y, double size, double spacing, int weight, String anchor, String text) =>
    '  <text x="$x" y="$y" font-family="Inter, Arial, sans-serif" font-size="$size" font-weight="$weight" '
    'letter-spacing="$spacing" text-anchor="$anchor" fill="${_hex(AppColors.primaryDark)}">$text</text>\n';

void _writeSvgs() {
  const dir = 'assets/brand';
  Directory(dir).createSync(recursive: true);
  File('$dir/aiovy-symbol.svg').writeAsStringSync(_svg(160, 160, _svgShapes(), 'AIOVY'));
  File(
    '$dir/aiovy-symbol-mono.svg',
  ).writeAsStringSync(_svg(160, 160, _svgShapes(mono: AppColors.primaryDark), 'AIOVY'));
  File(
    '$dir/aiovy-symbol-mono-white.svg',
  ).writeAsStringSync(_svg(160, 160, _svgShapes(mono: Colors.white), 'AIOVY'));
  // Horizontal: symbol 64 high, name and tagline to the right.
  File('$dir/aiovy-logo-horizontal.svg').writeAsStringSync(
    _svg(
      300,
      64,
      _svgShapes(scale: 0.4) +
          _text(76, 32, 34, 6.8, 500, 'start', 'AIOVY') +
          _text(77, 52, 9.6, 2.1, 600, 'start', 'MATERNAL CARE INTELLIGENCE'),
      'AIOVY, Maternal Care Intelligence',
    ),
  );
  // Primary: symbol centred above the name and tagline.
  File('$dir/aiovy-logo-primary.svg').writeAsStringSync(
    _svg(
      260,
      250,
      _svgShapes(x: 74, y: 0, scale: 0.7) +
          _text(133.4, 182, 40, 8, 500, 'middle', 'AIOVY') +
          _text(130, 210, 11.5, 2.5, 600, 'middle', 'MATERNAL CARE INTELLIGENCE'),
      'AIOVY, Maternal Care Intelligence',
    ),
  );
}

Future<void> _png(WidgetTester tester, String path, int px, CustomPainter painter, {Color? background}) async {
  await _capture(
    tester,
    Container(
      width: px.toDouble(),
      height: px.toDouble(),
      color: background ?? Colors.transparent,
      child: CustomPaint(painter: painter),
    ),
    Size(px.toDouble(), px.toDouble()),
    path,
  );
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('brand preview sheet', skip: _preview.isEmpty, (tester) async {
    await _capture(tester, _sheet(), const Size(900, 760), '$_preview/brand_sheet.png', dpr: 2);
  });

  testWidgets('export brand assets', skip: !_export, (tester) async {
    _writeSvgs();
    const res = 'android/app/src/main/res';
    const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
    for (final MapEntry(key: d, value: f) in densities.entries) {
      // Legacy launcher icon (48 dp): blush rounded tile.
      await _png(
          tester, '$res/mipmap-$d/ic_launcher.png', (48 * f).round(), BrandMarkPainter(showTile: true, inset: 0.14));
      // Adaptive icon foreground (108 dp canvas, symbol inside the 66 dp safe zone).
      await _png(tester, '$res/mipmap-$d/ic_launcher_foreground.png', (108 * f).round(), BrandMarkPainter(inset: 0.24));
      // Launch-screen symbol (96 dp), centred on ivory by launch_background.xml.
      await _png(tester, '$res/drawable-$d/launch_symbol.png', (96 * f).round(), BrandMarkPainter());
    }
    // Web: tile icons, full-bleed maskable icons (safe zone = central 80 %), favicon.
    for (final px in [192, 512]) {
      await _png(tester, 'web/icons/Icon-$px.png', px, BrandMarkPainter(showTile: true, inset: 0.14));
      await _png(tester, 'web/icons/Icon-maskable-$px.png', px, BrandMarkPainter(inset: 0.2),
          background: AppColors.blush);
    }
    await _png(tester, 'web/favicon.png', 48, BrandMarkPainter(inset: 0.04));
  });
}
