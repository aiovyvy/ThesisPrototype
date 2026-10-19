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
            padding: const EdgeInsets.fromLTRB(AppSpacing.margin, 20, AppSpacing.margin, AppSpacing.xl),
            children: [
              Text(
                '${Fmt.greeting(now)}, ${scope.clinician.displayName}',
                style: AppTextStyles.headlineMd,
              ),
              const SizedBox(height: 2),
              Text(Fmt.date(now), style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              _StartAssessment(onTap: () => AppNavigator.push(context, const AssessmentInputScreen())),
              const SizedBox(height: AppSpacing.lg),
              SectionTitle(
                'Needs review',
                caption: needsReview.isEmpty ? null : 'Latest result is High Risk',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (needsReview.isEmpty)
                const InfoNote(
                  icon: Icons.check_circle_outline,
                  text: 'No patient currently has a High Risk result.',
                  background: AppColors.riskLowTint,
                  iconColor: AppColors.riskLow,
                )
              else
                GroupedList(
                  children: [
                    for (final p in needsReview) PatientListRow(patient: p, onTap: () => openPatient(p.id)),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              _TodayOverview(
                total: today.length,
                low: count(RiskLevel.low),
                moderate: count(RiskLevel.moderate),
                high: count(RiskLevel.high),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.white.withAlpha(38), shape: BoxShape.circle),
                    child: const Icon(Icons.add, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
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

/// Today's assessments: total and a count per risk level.
class _TodayOverview extends StatelessWidget {
  const _TodayOverview({required this.total, required this.low, required this.moderate, required this.high});

  final int total;
  final int low;
  final int moderate;
  final int high;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Today: $total assessments',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text('Today', style: AppTextStyles.labelLg)),
                Text('$total', style: AppTextStyles.metric),
                const SizedBox(width: 6),
                Text(
                  total == 1 ? 'assessment' : 'assessments',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Count(level: RiskLevel.high, count: high)),
              const SizedBox(width: 8),
              Expanded(child: _Count(level: RiskLevel.moderate, count: moderate)),
              const SizedBox(width: 8),
              Expanded(child: _Count(level: RiskLevel.low, count: low)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.level, required this.count});

  final RiskLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${level.label}: $count',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(color: level.tint, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(level.icon, size: 15, color: level.color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    level.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSm.copyWith(color: level.textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$count', style: AppTextStyles.headlineMd.tabular.copyWith(color: level.textColor)),
          ],
        ),
      ),
    );
  }
}
