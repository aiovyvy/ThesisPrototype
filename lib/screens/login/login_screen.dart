import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_clinician.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../navigation/route_session.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/form_fields.dart';

/// Stitch: doctor_login. Prototype login – any non-empty credentials work.
class LoginScreen extends StatefulWidget implements RestorableWebPage {
  const LoginScreen({super.key});

  @override
  String get restorableWebLocation => '/login';
  @override
  bool get requiresDemoAccess => false;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: MockClinician.demoEmail);
  final _password = TextEditingController(text: MockClinician.demoPassword);
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500)); // simulated auth
    if (!mounted) return;
    AppNavigator.currentTab.value = ShellTab.home;
    AppNavigator.completeSignIn(context, const MainShell());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppLayout.page(context, top: AppSpacing.lg, bottom: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Back to Welcome when opened from there; after sign-out
                      // there is nothing to go back to.
                      if (Navigator.of(context).canPop()) ...[
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const AiovyWordmark(height: 36),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text('Enter the AIOVY demo', style: AppTextStyles.displayLg),
                  ),
                  const SizedBox(height: 6),
                  Text('Demo access only. No account is required.',
                      style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.lg),
                  // Before the fields: this sign-in checks nothing.
                  const DemoAccessBanner(),
                  if (kIsWeb) ...[
                    const SizedBox(height: 12),
                    const InfoNote(
                      title: 'Temporary DEMO-ONLY browser session',
                      text: 'Sign in enables a non-secret demo-mode marker for this tab. It survives refresh, '
                          'but does not save credentials or patient data and is not authentication. Logout clears it.',
                      icon: Icons.science_outlined,
                      circleIcon: false,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _card(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.versionShort,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return AppCard(
      radius: AppRadius.xl,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel(label: 'Demo email or ID'),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _email,
                  hint: 'name@hospital.org',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: null,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email or clinical ID' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                const FieldLabel(label: 'Demo password'),
                AppTextField(
                  controller: _password,
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: null,
                  onSubmitted: (_) => _signIn(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  suffix: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Sign in',
                  trailingIcon: Icons.arrow_forward,
                  loading: _loading,
                  onPressed: _signIn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// States plainly that the sign-in is not real authentication.
class DemoAccessBanner extends StatelessWidget {
  const DemoAccessBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Demo access. ${AppStrings.demoAccessNote}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.riskModerateTint,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.riskModerate.withAlpha(90)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.lock_open_outlined, size: 20, color: AppColors.riskModerateText),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.demoAccess,
                    style: AppTextStyles.labelLg.copyWith(color: AppColors.riskModerateText, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text(AppStrings.demoAccessNote, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
