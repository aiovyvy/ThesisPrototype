import 'package:flutter/material.dart';

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
import '../../widgets/explanation_widgets.dart';
import '../research/research_screen.dart';

/// Deterministic explanations of the supplied prediction, with no clinical
/// rules or generated medical interpretations.
class ShapScreen extends StatelessWidget {
  const ShapScreen({super.key, required this.assessment});

  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final r = assessment.result;
    final level = r.riskLevel;
    final framing = ContributionFraming.of(r);
    final ranked = rankedContributions(r.featureContributions);
    final scale = contributionScale(ranked);
    return Scaffold(
      appBar: const AppHeader(title: 'Explanation', showLogo: false),
      body: AppStateBuilder(
        builder: (context, scope) {
          final s = scope.settings;
          return ListView(
            padding: AppLayout.page(context, top: AppSpacing.md, bottom: AppSpacing.xl),
            children: [
              Semantics(
                header: true,
                child: Text('Why did AI predict this?', style: AppTextStyles.headlineMd),
              ),
              const SizedBox(height: 6),
              Text('Patient ${assessment.patientId}',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.primarySoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.isDemo ? 'SIMULATED ESTIMATE' : 'MODEL ESTIMATE', style: AppTextStyles.overline),
                    const SizedBox(height: 6),
                    Text(level.label, style: AppTextStyles.headlineMd.copyWith(color: level.textColor)),
                    const SizedBox(height: 8),
                    Text(
                        'The ${r.isDemo ? 'demo classifier' : 'model'} assigned '
                        '${Fmt.percent(r.probabilities[level] ?? 0)} probability to ${level.label} '
                        'using the six entered indicators. This is a model estimate, not a diagnosis.',
                        style: AppTextStyles.bodyMd),
                    if (r.isDemo) ...[
                      const SizedBox(height: 10),
                      const Text(AppStrings.demoOutputTag),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoNote(
                title: 'What shaped this prediction',
                text: framing.summary(ranked, valueText: (i) => Fmt.indicator(i, assessment.indicators, s)),
                icon: Icons.psychology_outlined,
              ),
              const SizedBox(height: 12),
              InfoNote(
                title: r.isDemo ? 'How to read demo scores' : 'How to read SHAP values',
                text: r.isDemo
                    ? 'Positive demo scores point toward higher risk; negative scores point toward lower risk. '
                        'Zero means no contribution. These are simulated heuristic scores, not SHAP values.'
                    : 'SHAP compares this prediction with the model baseline (its reference output). '
                        'Positive (+) supports ${level.label}; negative (minus) opposes ${level.label}. '
                        'Zero means no contribution. These directions apply to the predicted class, '
                        'including Low Risk. A larger absolute value means more model influence. '
                        'Values use probability units: +0.10 contributes 10 percentage points toward '
                        'this class relative to the baseline; it is not a measured change in health.',
                icon: Icons.compare_arrows,
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text('All six indicators', style: AppTextStyles.labelLg)),
                    const SizedBox(height: 6),
                    Text(
                        'Ranked by absolute contribution, largest first. Equal values share a rank. '
                        'Bars point left for negative and right for positive contributions.',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    ContributionLegend(framing: framing),
                    const SizedBox(height: 18),
                    for (var i = 0; i < ranked.length; i++) ...[
                      if (i > 0) const Divider(height: 28),
                      Text(
                          'Rank ${ranked.indexWhere((f) => f.value.abs() == ranked[i].value.abs()) + 1}'
                          ' / ${framing.relativeToPrediction ? 'SHAP contribution' : 'Demo contribution'}',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      ContributionBar(
                        key: ValueKey('explanation-${ranked[i].indicator.name}'),
                        contribution: ranked[i],
                        framing: framing,
                        valueText: Fmt.indicator(ranked[i].indicator, assessment.indicators, s),
                        maxAbs: scale,
                      ),
                    ],
                    if (ranked.length != 6) ...[
                      const SizedBox(height: 12),
                      Text(
                          'Only ${ranked.length} contributions are available for this assessment. '
                          'Missing contributions are not treated as zero.',
                          style: AppTextStyles.bodySm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoNote(
                title: 'What the model can and cannot tell you',
                text: r.isDemo
                    ? 'This demo uses simulated heuristic scores, not a trained model. '
                        'It cannot establish a diagnosis, explain a medical cause, or decide treatment.'
                    : 'The model classifies patterns in the six entered indicators using what it learned '
                        'from the UCI Maternal Health Risk dataset. SHAP explains which inputs supported or '
                        'opposed this model prediction. It does not explain what medically caused a condition. '
                        'An opposing contribution does not prove an indicator is healthy or protective. '
                        'The result cannot establish a diagnosis, guarantee an outcome, or decide treatment. '
                        'Clinical history and other information outside these six inputs are not assessed.',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.isDemo ? 'Source: built-in demo classifier (simulated)' : 'Model: ${r.modelName}',
                        style: AppTextStyles.labelMd),
                    const SizedBox(height: 6),
                    Text(
                        'Explanations use fixed wording and the returned contributions. '
                        'No generative AI or external language model is used.',
                        style: AppTextStyles.bodySm),
                    const SizedBox(height: 4),
                    LinkButton(
                      label: 'How AIOVY Works',
                      trailingIcon: Icons.chevron_right,
                      onPressed: () => AppNavigator.push(context, const ResearchScreen()),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
