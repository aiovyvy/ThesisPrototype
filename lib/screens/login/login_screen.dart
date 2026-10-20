import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock/mock_clinician.dart';
import '../../data/repositories/app_settings.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../state/app_scope.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/settings_widgets.dart';

/// Stitch: doctor_login. Prototype login – any non-empty credentials work.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    AppNavigator.resetTo(context, const MainShell());
  }

  void _showInfo(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: AppTextStyles.headlineSm),
        content: Text(body, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
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
                  const Align(alignment: Alignment.centerLeft, child: AiovyWordmark(height: 36)),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text('Sign in', style: AppTextStyles.displayLg),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Maternal risk assessment for barangay midwives and obstetric teams.',
                    style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _card(settings),
                  const SizedBox(height: AppSpacing.md),
                  const InfoNote(
                    icon: Icons.science_outlined,
                    title: 'Thesis prototype',
                    text: 'Any non-empty email and password signs in. Use demo records only, '
                        'never real patient information.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: LinkButton(
                      label: 'Need help signing in?',
                      leadingIcon: Icons.help_outline,
                      color: AppColors.onSurfaceVariant,
                      onPressed: () => _showInfo(
                        'Access help',
                        'This is a thesis prototype. Any non-empty email or clinical ID and password will sign you in.',
                      ),
                    ),
                  ),
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

  Widget _card(AppSettings settings) {
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
                const FieldLabel(label: 'Email or clinical ID'),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _email,
                  hint: 'e.g. dr.santos@hospital.org',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email or clinical ID' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                FieldLabel(
                  label: 'Password',
                  trailing: LinkButton(
                    label: 'Forgot password?',
                    style: AppTextStyles.labelSm,
                    onPressed: () => _showInfo(
                      'Reset password',
                      'Password reset is handled by your institution. In this prototype any password works.',
                    ),
                  ),
                ),
                AppTextField(
                  controller: _password,
                  hint: 'Enter clinical password',
                  icon: Icons.lock_outline,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _signIn(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  suffix: LinkButton(
                    label: _obscure ? 'Show' : 'Hide',
                    style: AppTextStyles.labelSm,
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MergeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Remember this workstation', style: AppTextStyles.labelLg),
                            const SizedBox(height: 2),
                            Text(
                              'Prototype setting · not stored on the device',
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      AiovySwitch(
                        value: settings.rememberWorkstation,
                        onChanged: (v) => setState(() => settings.rememberWorkstation = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
