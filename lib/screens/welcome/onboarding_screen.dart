import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/maternal_indicators.dart';
import '../../models/risk_level.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/route_session.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../assessment/indicator_input_card.dart';
import '../login/login_screen.dart';

/// Three short pages (what it does, how it explains, what it is not), then
/// sign-in. "Skip" goes straight to sign-in from any page.
///
/// The illustrations are built from the app's own UI elements and carry no
/// numbers, so nothing on these pages could be mistaken for patient data or
/// model output.
class OnboardingScreen extends StatefulWidget implements RestorableWebPage {
  const OnboardingScreen({super.key});

  @override
  String get restorableWebLocation => '/onboarding';
  @override
  bool get requiresDemoAccess => false;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _content = [
    (
      'Six routine measurements',
      "Enter age, blood pressure, blood glucose, body temperature and the mother's heart rate "
          'to get a low, moderate or high risk estimate.',
    ),
    (
      'See what drove each estimate',
      'Explainable AI (SHAP) shows which measurements supported the estimate and which counted against it.',
    ),
    (
      'Support, not a substitute',
      'AIOVY assists midwives, OB-GYNs and care teams. It does not replace clinical judgment: '
          'the decision stays with you.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toSignIn() {
    final session = RouteSession.maybeOf(context);
    if (session != null) {
      session.go('/login');
    } else {
      Navigator.of(context).pushReplacement(AppNavigator.route(const LoginScreen()));
    }
  }

  void _next() {
    if (_index == _content.length - 1) return _toSignIn();
    _pages.nextPage(
      duration: MediaQuery.disableAnimationsOf(context) ? const Duration(milliseconds: 1) : AppMotion.push,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _content.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Top bar: back to Welcome, symbol, Skip.
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                        onPressed: () {
                          final session = RouteSession.maybeOf(context);
                          if (session != null) {
                            session.go('/');
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                      ),
                      const Spacer(),
                      const AiovyLogoMark(size: 28),
                      const Spacer(),
                      LinkButton(label: 'Skip', color: AppColors.onSurfaceVariant, onPressed: _toSignIn),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _content.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _Page(
                      art: switch (i) {
                        0 => const _MeasurementsArt(),
                        1 => const _ExplainArt(),
                        _ => const _SupportArt(),
                      },
                      title: _content[i].$1,
                      body: _content[i].$2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Dots(count: _content.length, index: _index),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: last ? 'Continue to sign in' : 'Next',
                        trailingIcon: Icons.arrow_forward,
                        onPressed: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(child: Center(child: art)),
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text(title, style: AppTextStyles.headlineMd),
              ),
              const SizedBox(height: 10),
              Text(body, style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page position. Announced as "Page n of 3".
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? AppColors.primary : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
  }
}

/// A frame shared by the three illustrations.
class _ArtCard extends StatelessWidget {
  const _ArtCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// The six inputs as labelled chips.
class _MeasurementsArt extends StatelessWidget {
  const _MeasurementsArt();

  @override
  Widget build(BuildContext context) {
    return _ArtCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in Indicator.values)
            Container(
              width: 120,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  Icon(i.icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      fieldLabel(i),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Three risk levels and unlabelled contribution bars: the shape of a
/// result, not a result.
class _ExplainArt extends StatelessWidget {
  const _ExplainArt();

  @override
  Widget build(BuildContext context) {
    Widget bar(double frac, bool supports) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 8,
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final half = c.maxWidth / 2;
                    final len = half * frac;
                    return SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          Positioned(
                            left: supports ? half : half - len,
                            width: len,
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: supports ? AppColors.shapPositive : AppColors.shapNegative,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          Positioned(
                            left: half - 0.75,
                            width: 1.5,
                            top: 0,
                            bottom: 0,
                            child: const ColoredBox(color: AppColors.outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
    return _ArtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final l in RiskLevel.values)
                Pill(
                  text: l.shortLabel,
                  icon: l.icon,
                  background: l.tint,
                  foreground: l.textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
            ],
          ),
          const SizedBox(height: 14),
          bar(0.85, true),
          bar(0.45, false),
          bar(0.25, true),
        ],
      ),
    );
  }
}

/// The estimate informs; the clinician decides.
class _SupportArt extends StatelessWidget {
  const _SupportArt();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String text, {bool emphasis = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: emphasis ? AppColors.primarySoft : AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: emphasis ? Border.all(color: AppColors.primary.withAlpha(90)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: emphasis ? AppColors.primaryDark : AppColors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.labelLg.copyWith(color: emphasis ? AppColors.primaryDark : AppColors.onSurface),
                ),
              ),
            ],
          ),
        );
    return _ArtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          step(Icons.insights, 'Model estimate'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.arrow_downward, size: 18, color: AppColors.outline),
          ),
          step(Icons.person_outline, 'Your clinical judgment', emphasis: true),
        ],
      ),
    );
  }
}
