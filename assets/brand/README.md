# AIOVY brand assets

The symbol is a mother in profile, looking down at the baby she holds, with her hair flowing into the cradling arm
and a single leaf. Its geometry is defined once in [`lib/core/brand/brand_mark.dart`](../../lib/core/brand/brand_mark.dart)
as SVG path data on a 160 × 160 canvas.

| File | Use |
|---|---|
| `aiovy-symbol.svg` | Symbol, full colour: launcher icon, compact headers |
| `aiovy-symbol-mono.svg` | Symbol, single colour (deep mauve) |
| `aiovy-symbol-mono-white.svg` | Symbol, white, for dark or coloured backgrounds |
| `aiovy-logo-horizontal.svg` | Symbol beside the name and tagline: headers, sign-in |
| `aiovy-logo-primary.svg` | Symbol above the name and tagline: welcome, documents |

In the app, the same variants are Flutter widgets in `lib/widgets/aiovy_logo.dart`: `AiovyLogoMark`, `AiovyWordmark`
(horizontal) and `AiovyLogoStacked` (primary). Each accepts `monochrome:`.

## Colours

| Role | Hex |
|---|---|
| Mother (muted rose) | `#A65B76` |
| Baby (deep mauve) | `#82445F` |
| Leaf, wrap (soft rose) | `#D29AAE` |
| Icon tile (blush) | `#F8DDE3` |
| Background (warm ivory) | `#FAF8F6` |

The name is set in Inter Medium with wide tracking. In the SVG files the text is live `<text>`, so it renders in Inter
only where Inter is installed. Outline the text before using the logos in print.

## Regenerating

These files, the Android launcher icons (`ic_launcher`, `ic_launcher_foreground`), the Android launch image
(`launch_symbol`) and the web icons and favicon are all generated from the geometry:

```bash
flutter test test/brand_assets_test.dart --dart-define=BRAND_EXPORT=true
```

Preview every variant on one sheet:

```bash
flutter test test/brand_assets_test.dart --dart-define=BRAND_PREVIEW=<folder>
```

## Status

This is an original drawing made for the thesis prototype, based on the team's concept sheet. It has **not** had a
trademark search or similarity review, so its uniqueness or registrability has not been established.
