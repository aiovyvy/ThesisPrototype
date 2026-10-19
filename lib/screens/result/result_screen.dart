import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/assessment.dart';
import '../../models/risk_level.dart';
import '../../navigation/app_navigator.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/explanation_widgets.dart';
import '../../widgets/patient_widgets.dart';
import '../assessment/assessment_input_screen.dart';
import '../patient_profile/patient_profile_screen.dart';
import '../shap/shap_screen.dart';

/// Stitch: risk_classification_result
///
/// Two modes, derived from the repository:
/// * new result (not saved yet) – sticky "Save Assessment" bar, and leaving
///   asks before the result is discarded;
/// * saved / historical result (opened from a patient's history) – read
///   only; the header back button returns to the record.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.assessment});

  final Assessment assessment;

  void _save(BuildContext context) {
    final scope = AppScope.of(context);
    scope.repository.saveAssessment(assessment);
    HapticFeedback.lightImpact();
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(AppNavigator.route(PatientProfileScreen(patientId: assessment.patientId)));
    AppNavigator.showSnack('Assessment saved to ${assessment.patientId}\'s record');
  }

  Future<void> _assessAnother(BuildContext context) async {
    final discard = await confirmDiscard(
      context,
      title: 'Discard this result?',
      message: 'This result for Patient ${assessment.patientId} has not been saved. '
          'Starting a new assessment will discard it.',
      discardLabel: 'Discard & Start New',
      keepLabel: 'Keep Reviewing',
    );
    if (!discard || !context.mounted) return;
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(AppNavigator.route(const AssessmentInputScreen()));
  }

  Future<void> _confirmBack(BuildContext context) async {
    final discard = await confirmDiscard(
      context,
      title: 'Discard this result?',
      message: 'This result has not been saved to Patient ${assessment.patientId}\'s record. '
          'Going back returns to the indicator inputs and discards it.',
      keepLabel: 'Keep Reviewing',
    );
    if (discard && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, scope) {
        final s = scope.settings;
        final saved = scope.repository.isSaved(assessment);
        final r = assessment.result;
        final level = r.riskLevel;
        final framing = ContributionFraming.of(r);
        final top = r.featureContributions.take(3).toList();
        final scale = contributionScale(r.featureContributions);
        void openExplanation() => AppNavigator.push(context, ShapScreen(assessment: assessment));

        return PopScope(
          canPop: saved,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmBack(context);
          },
          child: Scaffold(
            appBar: AppHeader(title: saved ? 'Saved result' : 'Risk result', showLogo: false),
            bottomNavigationBar: saved
                ? null
                : _ResultActions(onSave: () => _save(context), onAssessAnother: () => _assessAnother(context)),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.md, AppSpacing.margin, AppSpacing.xl),
              children: [
                // 1. The verdict
                _Verdict(assessment: assessment, saved: saved),
                // 2. Risk-related alert, directly under the verdict
                if (level == RiskLevel.high && s.highRiskAlerts) ...[
                  const SizedBox(height: 12),
                  const InfoNote(
                    title: 'High-risk classification',
                    text: 'Prompt review by the attending obstetric team is recommended.',
                    icon: Icons.notification_important_outlined,
                    background: AppColors.riskHighTint,
                    iconColor: AppColors.riskHigh,
                    borderColor: Color(0x33B42318),
                  ),
                ],
                const SizedBox(height: 12),
                // 3. All three class probabilities
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Probability by risk level', style: AppTextStyles.labelLg),
                      ),
                      if (r.isDemo) ...[const SizedBox(height: 6), const _DemoTag()],
                      const SizedBox(height: 14),
                      ProbabilityBars(result: r),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 4. Why: the main factors inline, the full chart one tap away
                AppCard(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Main factors', style: AppTextStyles.labelLg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        framing.summary(r.featureContributions),
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      ContributionLegend(framing: framing),
                      const SizedBox(height: 14),
                      for (var i = 0; i < top.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        ContributionBar(
                          contribution: top[i],
                          framing: framing,
                          valueText: Fmt.indicator(top[i].indicator, assessment.indicators, s),
                          maxAbs: scale,
                          showDescription: false,
                        ),
                      ],
                      const SizedBox(height: 4),
                      const Divider(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: LinkButton(
                          label: 'See all 6 indicators',
                          trailingIcon: Icons.arrow_forward,
                          onPressed: openExplanation,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 5. What was entered
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Entered values', style: AppTextStyles.labelLg),
                      ),
                      const SizedBox(height: 12),
                      IndicatorGrid(indicators: assessment.indicators, settings: s),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 6. Single supporting notice
                InfoNote(
                  icon: Icons.verified_user_outlined,
                  text: '${AppStrings.decisionNotice} Model: ${r.modelName}.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sticky bottom actions for a new, unsaved result.
class _ResultActions extends StatelessWidget {
  const _ResultActions({required this.onSave, required this.onAssessAnother});

  final VoidCallback onSave;
  final VoidCallback onAssessAnother;

  @override
  Widget build(BuildContext context) {
    return StickyActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: 'Save to patient record', leadingIcon: Icons.save_outlined, onPressed: onSave),
          const SizedBox(height: 4),
          Center(
            child: LinkButton(
              label: 'Discard and assess another patient',
              color: AppColors.onSurfaceVariant,
              onPressed: onAssessAnother,
            ),
          ),
        ],
      ),
    );
  }
}

/// The verdict: one large, risk-coloured label with the model's probability
/// for it. Patient, time, assessor and save state sit above it.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.assessment, required this.saved});

  final Assessment assessment;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final r = assessment.result;
    final level = r.riskLevel;
    final p = r.probabilities[level] ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: level.tint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: level.color.withAlpha(70)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient ${assessment.patientId}', style: AppTextStyles.labelLg),
                    Text(
                      Fmt.relative(assessment.timestamp),
                      style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(
                text: saved ? 'Saved' : 'Not saved',
                icon: saved ? Icons.check : Icons.edit_note,
                background: AppColors.surfaceLowest,
                foreground: saved ? AppColors.riskLow : AppColors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            label: 'Risk classification: ${level.label}. Model probability ${Fmt.percent(p)}.',
            excludeSemantics: true,
            child: Row(
              children: [
                IconTile(
                  icon: level.icon,
                  size: 52,
                  iconSize: 30,
                  radius: 14,
                  background: AppColors.surfaceLowest,
                  foreground: level.color,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level.label, style: AppTextStyles.headlineLg.copyWith(color: level.textColor)),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Model probability '),
                            TextSpan(
                              text: Fmt.percent(p),
                              style: AppTextStyles.labelLg.tabular.copyWith(color: level.textColor),
                            ),
                          ],
                        ),
                        style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_summaryFor(level), style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface)),
          if (saved) ...[
            const SizedBox(height: 6),
            Text(
              '${assessment.type} · ${assessment.assessedBy}',
              style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Pill(
        text: AppStrings.demoOutputTag,
        icon: Icons.science_outlined,
        background: AppColors.surfaceLow,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      ),
    );
  }
}

/// One plain-language line under the verdict.
String _summaryFor(RiskLevel level) => switch (level) {
      RiskLevel.low => 'The model associates these indicators with low maternal risk.',
      RiskLevel.moderate => 'Some indicators are associated with elevated maternal risk.',
      RiskLevel.high => 'Several indicators are associated with high maternal risk.',
    };
