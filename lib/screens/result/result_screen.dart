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
import '../../navigation/route_session.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_header.dart';
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
class ResultScreen extends StatelessWidget implements TemporaryWebPage {
  const ResultScreen({super.key, required this.assessment});

  final Assessment assessment;

  @override
  String get temporaryWebLocation => '/result';

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
        final top = rankedContributions(r.featureContributions).take(3).toList();
        final scale = contributionScale(r.featureContributions);
        void openExplanation() => AppNavigator.push(context, ShapScreen(assessment: assessment));

        return PopScope(
          canPop: saved,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmBack(context);
          },
          child: Scaffold(
            appBar: AppHeader(title: saved ? 'Saved result' : 'Risk result', showLogo: false),
            // The footer occupies its own measured space. The scroll viewport
            // never extends underneath it, even when button text wraps.
            body: Column(children: [
              Expanded(
                  child: ListView(
                key: const ValueKey('result-scroll'),
                padding: AppLayout.page(context, top: AppSpacing.md, bottom: saved ? AppSpacing.xl : AppSpacing.md),
                children: [
                  // 1. The verdict
                  // 2. Includes the high-risk alert, at the point of decision
                  _Verdict(
                      assessment: assessment,
                      saved: saved,
                      showHighRiskAlert: level == RiskLevel.high && s.highRiskAlerts),
                  const SizedBox(height: 12),
                  // 3. Why: the main factors inline, the full chart one tap away
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
                        ExplanationButton(onPressed: openExplanation),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 4. What was entered
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
                  const SizedBox(height: AppSpacing.md),
                  if (!saved) ...[
                    TextButton(
                      onPressed: () => _assessAnother(context),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: const Text('Discard and assess another patient', textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  // 5. The decision-support notice, once, next to the save action
                  Padding(
                    key: const ValueKey('result-disclaimer'),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.info_outline, size: 16, color: AppColors.outline),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.isDemo
                                ? 'Simulated by the built-in demo classifier, not the trained model. '
                                    '${AppStrings.decisionNotice}'
                                : 'Estimated by ${r.modelName}. ${AppStrings.decisionNotice}',
                            style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )),
              if (!saved) _ResultActions(onSave: () => _save(context))
            ]),
          ),
        );
      },
    );
  }
}

/// Sticky bottom actions for a new, unsaved result.
class _ResultActions extends StatelessWidget {
  const _ResultActions({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return StickyActionBar(
      key: const ValueKey('result-actions'),
      child: ElevatedButton(
        onPressed: onSave,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: AppTextStyles.labelLg.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md + 2)),
        ),
        child: const Text('Save to patient record', textAlign: TextAlign.center),
      ),
    );
  }
}

/// The verdict: one large, risk-coloured label with the model's probability
/// for it. Patient, time, assessor and save state sit above it.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.assessment, required this.saved, required this.showHighRiskAlert});

  final Assessment assessment;
  final bool saved;

  /// The Settings "high-risk alerts" option, shown inside the verdict so the
  /// classification and its caution are read together.
  final bool showHighRiskAlert;

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
          const SizedBox(height: 18),
          Text(r.isDemo ? 'SIMULATED ESTIMATE' : 'MODEL ESTIMATE', style: AppTextStyles.overline),
          const SizedBox(height: 2),
          Semantics(
            header: true,
            label:
                '${r.isDemo ? 'Simulated estimate' : 'Model estimate'}: ${level.label}, ${Fmt.percent(p)} probability.',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(level.icon, size: 30, color: level.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(level.label, style: AppTextStyles.headlineLg.copyWith(color: level.textColor)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProbabilityBars(result: r, trackColor: AppColors.surfaceLowest),
          if (r.isDemo) ...[const SizedBox(height: 12), const _DemoTag()],
          if (showHighRiskAlert) ...[
            Divider(height: 28, color: level.color.withAlpha(50)),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.notification_important_outlined, size: 20, color: AppColors.riskHigh),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'High-risk classification. ', style: AppTextStyles.labelLg),
                          const TextSpan(text: 'Prompt review by the attending obstetric team is recommended.'),
                        ],
                      ),
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        background: AppColors.surfaceLowest,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      ),
    );
  }
}
