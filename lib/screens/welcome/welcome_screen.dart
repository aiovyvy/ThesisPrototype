import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../navigation/app_navigator.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/buttons.dart';
import 'onboarding_screen.dart';
import '../login/login_screen.dart';

/// First screen: the brand, one sentence of purpose, and two clear choices.
///
/// The native launch screen (symbol on ivory) covers real start-up time;
/// this screen never waits on a timer. The logo settles in with a short fade
/// and rise, then the text and actions follow; both are usable at once, and
/// the motion is skipped when the system asks for reduced motion.
///
/// "Get started" shows a three-page introduction before sign-in; "Sign in"
/// goes straight there, which is how returning users skip the introduction
/// (the prototype stores nothing between launches).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Fade plus a small upward settle over [begin, end] of the timeline.
  Widget _enter(Widget child, double begin, double end, {double rise = 16}) {
    final a = CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: a,
      builder: (_, c) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, rise * (1 - a.value)), child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _LeafBackdrop()))),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          _enter(const Center(child: AiovyLogoStacked(symbolSize: 120)), 0, 0.65),
                          _enter(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                              child: Column(
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      // Non-breaking space: never leave "care." alone on a line.
                                      'Smarter support for maternal${String.fromCharCode(0xA0)}care.',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.headlineLg,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Explore maternal risk classification with synthetic examples. '
                                    'Research demonstration only; not clinically validated.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            0.3,
                            0.85,
                            rise: 10,
                          ),
                          _enter(
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  PrimaryButton(
                                    label: 'Get started',
                                    trailingIcon: Icons.arrow_forward,
                                    onPressed: () => AppNavigator.push(context, const OnboardingScreen()),
                                  ),
                                  const SizedBox(height: 10),
                                  SecondaryButton(
                                    label: 'Sign in',
                                    onPressed: () => AppNavigator.push(context, const LoginScreen()),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Demo access · Synthetic data only · ${AppStrings.versionShort}',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(
                                          color: AppColors.outline,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            0.45,
                            1,
                            rise: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One large, very quiet blush leaf bleeding off the top-right corner: an
/// echo of the leaf in the symbol. Flat colour, no gradient.
class _LeafBackdrop extends CustomPainter {
  const _LeafBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final s = (size.shortestSide * 1.1).clamp(320.0, 560.0);
    final o = Offset(size.width - s * 0.62, -s * 0.30);
    final leaf = Path()
      ..moveTo(o.dx + s * 0.10, o.dy + s * 0.95)
      ..cubicTo(o.dx + s * 0.05, o.dy + s * 0.55, o.dx + s * 0.35, o.dy + s * 0.20, o.dx + s * 0.95, o.dy + s * 0.05)
      ..cubicTo(o.dx + s * 1.00, o.dy + s * 0.55, o.dx + s * 0.70, o.dy + s * 0.90, o.dx + s * 0.10, o.dy + s * 0.95)
      ..close();
    canvas.drawPath(leaf, Paint()..color = AppColors.blush.withAlpha(110));
  }

  @override
  bool shouldRepaint(covariant _LeafBackdrop oldDelegate) => false;
}
