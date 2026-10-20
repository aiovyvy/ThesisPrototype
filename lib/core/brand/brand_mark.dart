/// Geometry of the AIOVY symbol: a mother's head and flowing hair that
/// curves down and around to cradle a baby, with a single leaf.
///
/// Defined once, as SVG path data on a 160 × 160 canvas. The Flutter painter
/// (`widgets/aiovy_logo.dart`), the exported `.svg` files and the launcher
/// icons are all generated from these shapes, so they cannot drift apart.
///
/// Pure Dart (no Flutter import) so tooling can read it too.
library;

/// Which brand colour a shape is painted in.
enum MarkTone {
  /// Muted rose: the mother.
  rose,

  /// Deep mauve: the baby.
  mauve,

  /// Soft rose: the leaf and the baby's wrap.
  soft,
}

/// One filled shape of the symbol: either an SVG path (absolute M/L/C/Q/Z
/// commands only) or a circle.
class MarkShape {
  const MarkShape.path(this.d, this.tone)
      : cx = 0,
        cy = 0,
        r = 0;
  const MarkShape.circle(this.cx, this.cy, this.r, this.tone) : d = null;

  final String? d;
  final double cx;
  final double cy;
  final double r;
  final MarkTone tone;

  bool get isCircle => d == null;
}

class BrandMark {
  BrandMark._();

  static const double canvas = 160;

  /// Painted in order (back to front). Shapes of different tones never
  /// touch, so the single-colour version still reads as separate forms.
  static const List<MarkShape> shapes = [
    // Mother: one silhouette. Her face in profile (forehead, nose, lips,
    // chin) looks down toward the baby; her hair falls from the crown down
    // her back and sweeps round into the arm that holds the baby – thick
    // at the back, tapering at the hand. (Profile drawn upright, then
    // rotated 25° so she inclines toward the child.)
    MarkShape.path(
      'M 86 25 C 90 30 91 36 90 44 '
      'C 92 48 94 52 93 55 '
      'C 90.5 56.5 88 56.5 86 56.5 '
      'C 87 59 85 61.5 83 63 '
      'C 82 66 80 67.5 77 67.5 '
      'C 73 68 69 67.5 66 67 '
      'C 58 76 56 86 58 96 '
      'C 62 114 78 126 100 128 '
      'C 112 129 126 128 136 124 '
      'C 128 138 112 146 94 146 '
      'C 64 146 40 128 34 104 '
      'C 28 80 34 50 48 32 '
      'C 58 18 74 14 86 25 Z',
      MarkTone.rose,
    ),
    // Baby's head, nestled just under the mother's chin.
    MarkShape.circle(90, 82, 13, MarkTone.mauve),
    // Baby's wrap: the swaddled body, lying diagonally along the arm from
    // the head down into the crook (not a symmetric curve, which would
    // read as a smile under the head).
    MarkShape.path(
        'M 82 99 C 92 99 104 96 112 92 C 116 100 110 112 96 118 C 84 122 72 118 70 112 C 72 106 76 101 82 99 Z',
        MarkTone.soft),
    // A single leaf rising beside the hand: growth and care.
    MarkShape.path('M 128 108 C 126 90 134 76 150 66 C 154 88 146 102 128 108 Z', MarkTone.soft),
  ];
}

/// Parses the small SVG path subset used in [BrandMark] into callbacks, so
/// the same data can drive a Flutter `Path` or any other renderer.
void parseMarkPath(
  String d, {
  required void Function(double x, double y) moveTo,
  required void Function(double x, double y) lineTo,
  required void Function(double x1, double y1, double x2, double y2, double x, double y) cubicTo,
  required void Function(double x1, double y1, double x, double y) quadTo,
  required void Function() close,
}) {
  final tokens = RegExp(r'[MLCQZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        moveTo(n(), n());
      case 'L':
        lineTo(n(), n());
      case 'C':
        cubicTo(n(), n(), n(), n(), n(), n());
      case 'Q':
        quadTo(n(), n(), n(), n());
      case 'Z':
        close();
      default:
        throw FormatException('Unsupported path command "$cmd" in brand mark');
    }
  }
}
