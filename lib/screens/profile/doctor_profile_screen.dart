import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/app_settings.dart';
import '../../navigation/app_navigator.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/settings_widgets.dart';
import '../login/login_screen.dart';
import '../research/research_screen.dart';
import '../settings/settings_screen.dart';

/// Stitch: doctor_profile
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign out of workstation?', style: AppTextStyles.headlineSm),
        content: Text('You will return to the clinical sign-in screen.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      AppNavigator.currentTab.value = ShellTab.home;
      AppNavigator.resetTo(context, const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No avatar here: it would only link to this same tab.
      appBar: const AppHeader(title: 'Profile', style: HeaderStyle.wordmark, showAvatar: false),
      body: AppStateBuilder(builder: (context, scope) {
        final repo = scope.repository;
        final c = scope.clinician;
        final assessments = repo.allAssessments;
        final patients = repo.patients;
        final complete = patients.where((p) => p.latest != null).length;
        final completePct = patients.isEmpty ? 0 : (complete / patients.length * 100).round();

        return ListView(
          padding: AppLayout.page(context, top: AppSpacing.md, bottom: AppSpacing.xl),
          children: [
            // Identity card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Plain initials. (The former "On shift" dot implied shift
                  // tracking the prototype does not have.)
                  ExcludeSemantics(
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                      child: Text(c.initials, style: AppTextStyles.headlineSm.copyWith(color: AppColors.primaryDark)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(c.displayName, style: AppTextStyles.headlineMd)),
                        const SizedBox(height: 4),
                        Text(
                          '${c.role} · ${c.affiliation}',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _StatCard(value: '${assessments.length}', label: 'Total\nAssessments')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _StatCard(value: '${patients.length}', label: 'Active\nPatients')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _StatCard(value: '$completePct%', label: 'Complete\nRecords')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Research'),
            SettingsGroup(children: [
              SettingsRow(
                icon: Icons.model_training,
                title: 'How AIOVY Works',
                subtitle: 'Pipeline, model comparison & SHAP',
                showChevron: true,
                onTap: () => AppNavigator.push(context, const ResearchScreen()),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Preferences'),
            SettingsGroup(children: [
              SettingsRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Units (${scope.settings.glucoseUnit.label}, ${scope.settings.tempUnit.label}), '
                    'alerts & privacy',
                showChevron: true,
                onTap: () => AppNavigator.push(context, const SettingsScreen()),
              ),
            ]),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              label: 'Sign Out',
              leadingIcon: Icons.logout,
              onPressed: () => _signOut(context),
            ),
            const VersionFooter(),
          ],
        );
      }),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value ${label.replaceAll('\n', ' ')}',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: AppTextStyles.headlineSm),
            ),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
