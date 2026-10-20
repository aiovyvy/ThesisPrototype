import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../navigation/app_navigator.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../login/login_screen.dart';

/// Welcome: what AIOVY does, in three factual lines, and one action.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: FadeTransition(
                  opacity: fade,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AiovyLogoMark(size: 72),
                              const SizedBox(height: AppSpacing.lg),
                              Semantics(
                                header: true,
                                child: Text(
                                  AppStrings.appName,
                                  style: AppTextStyles.displayLg.copyWith(color: AppColors.brandInk, letterSpacing: 1),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Maternal risk assessment that shows its reasoning.',
                                style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppCard(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                                child: Column(
                                  children: const [
                                    _Feature(
                                      icon: Icons.monitor_heart_outlined,
                                      title: 'Six routine measurements',
                                      text: 'Age, blood pressure, blood glucose, body temperature and heart rate.',
                                    ),
                                    Divider(height: 1),
                                    _Feature(
                                      icon: Icons.stacked_bar_chart,
                                      title: 'Low, moderate or high risk',
                                      text: "With the model's probability for each level.",
                                    ),
                                    Divider(height: 1),
                                    _Feature(
                                      icon: Icons.insights,
                                      title: 'Shows what drove the result',
                                      text: 'How much each measurement contributed, using SHAP.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Decision support only. It does not replace clinical judgment.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                PrimaryButton(
                                  label: 'Get started',
                                  trailingIcon: Icons.arrow_forward,
                                  onPressed: () => AppNavigator.replace(context, const LoginScreen()),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  AppStrings.versionShort,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: ExcludeSemantics(child: Icon(icon, size: 22, color: AppColors.primary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLg),
                  const SizedBox(height: 2),
                  Text(text, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
