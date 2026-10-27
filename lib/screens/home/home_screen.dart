import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/risk_level.dart';
import '../../navigation/app_navigator.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/patient_widgets.dart';
import '../../widgets/research_disclaimer.dart';
import '../assessment/assessment_input_screen.dart';
import '../patient_profile/patient_profile_screen.dart';

/// Home: start an assessment, see who needs review, and today's activity.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _recentCount = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Home', style: HeaderStyle.brand),
      body: AppStateBuilder(
        builder: (context, scope) {
          final repo = scope.repository;
          final now = DateTime.now();
          final today = repo.assessmentsOn(now);
          final recent = repo.allAssessments.take(_recentCount).toList();
          // Patients whose latest saved result is High, most recent first.
          final needsReview = repo.patients.where((p) => p.currentRisk == RiskLevel.high).toList();
          int count(RiskLevel l) => today.where((a) => a.result.riskLevel == l).length;
          void openPatient(String id) => AppNavigator.push(context, PatientProfileScreen(patientId: id));

          return ListView(
            padding: AppLayout.page(context, top: 20, bottom: AppSpacing.xl),
            children: [
              const ResearchDisclaimer(),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${Fmt.greeting(now)}, ${scope.clinician.displayName}',
                style: AppTextStyles.headlineMd,
              ),
              const SizedBox(height: 4),
              _TodaySummary(
                date: Fmt.date(now),
                total: today.length,
                counts: {for (final l in RiskLevel.values.reversed) l: count(l)},
              ),
              const SizedBox(height: AppSpacing.md),
              const PredictionModeNote(),
              _StartAssessment(onTap: () => AppNavigator.push(context, const AssessmentInputScreen())),
              const SizedBox(height: AppSpacing.lg),
              SectionTitle(
                'Needs review',
                caption: needsReview.isEmpty ? null : 'Latest model estimate is High Risk',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (needsReview.isEmpty)
                Text(
                  'No patient currently has a High Risk estimate.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                )
              else
                GroupedList(
                  children: [
                    for (final p in needsReview) PatientListRow(patient: p, onTap: () => openPatient(p.id)),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              SectionTitle(
                'Recent assessments',
                trailing: LinkButton(
                  label: 'All patients',
                  trailingIcon: Icons.chevron_right,
                  onPressed: () => AppNavigator.currentTab.value = ShellTab.patients,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (recent.isEmpty)
                const InfoNote(text: 'No assessments yet. Start with "New assessment".')
              else
                GroupedList(
                  children: [
                    for (final a in recent) AssessmentListRow(assessment: a, onTap: () => openPatient(a.patientId)),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Demo records only · no real patient data',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The screen's primary action: a solid rose panel, deliberately plain.
class _StartAssessment extends StatefulWidget {
  const _StartAssessment({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_StartAssessment> createState() => _StartAssessmentState();
}

class _StartAssessmentState extends State<_StartAssessment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(AppRadius.card);
    return Semantics(
      button: true,
      label: 'New assessment. Enter six maternal indicators to get a risk classification.',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: _pressed ? AppColors.primaryPressed : AppColors.primary,
          borderRadius: br,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 18, AppSpacing.md, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New assessment', style: AppTextStyles.headlineSm.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          'Enter six maternal indicators',
                          style: AppTextStyles.bodySm.copyWith(color: Colors.white.withAlpha(230)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line under the greeting: the date, today's assessment count, and how
/// many were estimated at each level. Plain text, no tiles.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.date, required this.total, required this.counts});

  final String date;
  final int total;
  final Map<RiskLevel, int> counts;

  @override
  Widget build(BuildContext context) {
    final meta = AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant);
    return Semantics(
      label: '$date. $total ${total == 1 ? 'assessment' : 'assessments'} today: '
          '${counts.entries.map((e) => '${e.value} ${e.key.label}').join(', ')}.',
      excludeSemantics: true,
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$date · $total today', style: meta),
          for (final e in counts.entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e.key.icon, size: 14, color: e.key.color),
                const SizedBox(width: 3),
                Text('${e.value} ${e.key.shortLabel}', style: meta.tabular),
              ],
            ),
        ],
      ),
    );
  }
}
