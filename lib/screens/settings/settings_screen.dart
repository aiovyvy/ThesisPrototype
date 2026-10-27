import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/app_settings.dart';
import '../../navigation/app_navigator.dart';
import '../../state/app_scope.dart';
import '../../widgets/aiovy_logo.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../../widgets/settings_widgets.dart';
import '../research/research_demo_screen.dart';

/// Stitch: settings. All controls are functional (in-memory only).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Really removes this session's records (it used to only show a message).
  Future<void> _confirmClearSession(BuildContext context) async {
    final repository = AppScope.of(context).repository;
    final n = repository.sessionAssessmentCount;
    if (n == 0) {
      AppNavigator.showSnack('Nothing to clear: no assessments were entered in this session.',
          icon: Icons.info_outline);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: AppColors.riskModerate, size: 32),
        title: Text('Clear session records?', style: AppTextStyles.headlineSm, textAlign: TextAlign.center),
        content: Text(
          'Removes the $n ${n == 1 ? 'assessment' : 'assessments'} entered since the app was opened. '
          'Only the synthetic demo records remain. This cannot be undone.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear records'),
          ),
        ],
      ),
    );
    if (ok == true) {
      repository.clearSession();
      AppNavigator.showSnack('Session records removed');
    }
  }

  void _showAdvisory(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.gavel, color: AppColors.primary, size: 30),
        title: Text('Clinical Advisory Notice', style: AppTextStyles.headlineSm, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AIOVY is an academic clinical decision-support prototype for maternal health risk classification. '
              'It does not replace professional clinical judgment or medical diagnosis. All patient records are '
              'synthetic. Results marked "Simulated" come from a built-in demo classifier, not the trained model.',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Acknowledge & Close', textAlign: TextAlign.center))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Settings', style: HeaderStyle.backCentered),
      body: AppStateBuilder(builder: (context, scope) {
        final s = scope.settings;
        return ListView(
          padding: AppLayout.page(context, top: AppSpacing.md, bottom: AppSpacing.xl),
          children: [
            const SectionLabel('Units'),
            SettingsGroup(children: [
              const SettingsRow(
                icon: Icons.speed,
                title: 'Blood Pressure',
                subtitle: 'Systolic & diastolic',
                trailing: Pill(
                  text: 'mmHg',
                  background: AppColors.surfaceContainer,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              SettingsRow(
                icon: Icons.water_drop_outlined,
                title: 'Blood Glucose',
                subtitle: 'Display and entry unit',
                trailing: SegmentedToggle<GlucoseUnit>(
                  semanticLabel: 'Blood glucose unit',
                  options: GlucoseUnit.values,
                  selected: s.glucoseUnit,
                  labelOf: (u) => u.label,
                  onChanged: (u) => s.glucoseUnit = u,
                ),
              ),
              SettingsRow(
                icon: Icons.device_thermostat,
                title: 'Body Temperature',
                subtitle: 'Display and entry unit',
                trailing: SegmentedToggle<TempUnit>(
                  semanticLabel: 'Body temperature unit',
                  options: const [TempUnit.celsius, TempUnit.fahrenheit],
                  selected: s.tempUnit,
                  labelOf: (u) => u.label,
                  onChanged: (u) => s.tempUnit = u,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Alerts'),
            SettingsGroup(children: [
              SettingsRow(
                icon: Icons.notifications_active_outlined,
                title: 'High-Risk Alerts',
                subtitle: 'Highlight High Risk results for prompt review',
                onTap: () {
                  HapticFeedback.selectionClick();
                  s.highRiskAlerts = !s.highRiskAlerts;
                },
                trailing: AiovySwitch(
                  value: s.highRiskAlerts,
                  semanticLabel: 'High-risk alerts',
                  onChanged: (v) => s.highRiskAlerts = v,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Privacy & Data'),
            SettingsGroup(children: [
              // No lock icon: nothing here is encrypted or access-controlled.
              const SettingsRow(
                icon: Icons.memory_outlined,
                title: 'Data Storage',
                subtitle: 'In memory only; lost when the app closes. Not encrypted. Synthetic data only.',
              ),
              SettingsRow(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Session Records',
                subtitle: scope.repository.sessionAssessmentCount == 0
                    ? 'No assessments entered in this session'
                    : '${scope.repository.sessionAssessmentCount} entered in this session · also cleared on sign-out',
                showChevron: true,
                onTap: () => _confirmClearSession(context),
              ),
              _PredictionSourceRow(isDemo: scope.classifier.isDemo, modelName: scope.classifier.modelName),
            ]),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('Research'),
            SettingsGroup(children: [
              SettingsRow(
                icon: Icons.science_outlined,
                title: 'Research Demonstration',
                subtitle: 'Experimental research model · six fixed examples only',
                showChevron: true,
                onTap: () => AppNavigator.pushLocation(context, '/research-demonstration', const ResearchDemoScreen()),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            const SectionLabel('About'),
            SettingsGroup(children: [
              SettingsRow(
                icon: Icons.medical_services_outlined,
                title: 'About AIOVY',
                subtitle: AppStrings.versionShort,
                showChevron: true,
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: AppStrings.appName,
                  applicationVersion: '1.0 · Thesis Prototype',
                  applicationIcon: const AiovyLogoMark(size: 48),
                  children: [
                    Text(AppStrings.thesisTitle, style: AppTextStyles.bodyMd),
                  ],
                ),
              ),
              const SettingsRow(
                icon: Icons.school_outlined,
                title: 'Research & Design Attribution',
                subtitle: 'Undergraduate Computer Science thesis project',
              ),
              SettingsRow(
                icon: Icons.gavel,
                title: 'Clinical Disclaimer',
                subtitle: 'Limitations of this prototype',
                showChevron: true,
                onTap: () => _showAdvisory(context),
              ),
            ]),
          ],
        );
      }),
    );
  }
}

/// Which classifier produces results in this build: the built-in simulation
/// or the trained model behind the API.
class _PredictionSourceRow extends StatelessWidget {
  const _PredictionSourceRow({required this.isDemo, required this.modelName});

  final bool isDemo;
  final String modelName;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      icon: isDemo ? Icons.science_outlined : Icons.model_training,
      title: 'Predictions',
      subtitle: isDemo
          ? 'Simulated by the built-in demo classifier, not the trained model'
          : 'Trained model ($modelName) via the AIOVY API. Seeded demo records stay simulated.',
    );
  }
}
