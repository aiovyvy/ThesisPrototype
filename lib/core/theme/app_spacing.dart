import 'package:flutter/material.dart';

/// Spacing, radius and elevation tokens (4 pt grid).
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal page margin. 16 keeps content comfortable on 360 dp phones.
  static const double margin = 16;
  static const double gutter = 12;

  /// Minimum tap target used across the app (Android guideline).
  static const double minTap = 48;

  /// Height of numeric indicator inputs: larger than [minTap] so values are
  /// easy to hit and read at arm's length.
  static const double inputHeight = 56;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double card = 16;
  static const double xl = 20;
  static const double pill = 999;
}

/// Surfaces are separated by hairline borders; shadows are reserved for
/// things that float above the content (sticky action bars, sheets).
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A2D1924), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F2D1924), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> header = [];

  /// Sticky bottom action bars.
  static const List<BoxShadow> bar = [
    BoxShadow(color: Color(0x142D1924), blurRadius: 16, offset: Offset(0, -4)),
  ];
}
