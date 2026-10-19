import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/assessment.dart';
import '../../models/risk_level.dart';
import '../../models/risk_result.dart';
import '../../navigation/app_navigator.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/explanation_widgets.dart';
import '../research/research_screen.dart';

/// Every indicator's contribution to one result as a diverging bar chart,
/// largest first. Wording comes from [ContributionFraming] so it matches what
/// the classifier's numbers mean. Method details sit in a collapsible card.
class ShapScreen extends StatelessWidget {
  const ShapScreen({super.key, required this.assessment});

  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final r = assessment.result;
    final level = r.riskLevel;
    final framing = ContributionFraming.of(r);
    return Scaffold(
      appBar: const AppHeader(title: 'Explanation', showLogo: false),
      body: AppStateBuilder(
        builder: (context, scope) {
          final s = scope.settings;
          final scale = contributionScale(r.featureContributions);

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.md, AppSpacing.margin, AppSpacing.xl),
            children: [
              Semantics(
                header: true,
                child: Text('Why this result?', style: AppTextStyles.headlineMd),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'How each indicator moved the '),
                    TextSpan(
                      text: level.label,
                      style: AppTextStyles.bodyMd.weight(FontWeight.w600).copyWith(color: level.textColor),
                    ),
                    TextSpan(text: ' result for Patient ${assessment.patientId}.'),
                  ],
                ),
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              InfoNote(title: 'In short', text: framing.summary(r.featureContributions), icon: Icons.insights),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContributionLegend(framing: framing),
                    const SizedBox(height: 4),
                    Text(
                      'Longer bar = stronger influence. Sorted by influence.',
                      style: AppTextStyles.labelSm.weight(FontWeight.w500).copyWith(color: AppColors.outline),
                    ),
                    const SizedBox(height: 18),
                    for (var i = 0; i < r.featureContributions.length; i++) ...[
                      if (i > 0) const Divider(height: 28),
                      ContributionBar(
                        contribution: r.featureContributions[i],
                        framing: framing,
                        valueText: Fmt.indicator(r.featureContributions[i].indicator, assessment.indicators, s),
                        maxAbs: scale,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AboutCard(result: r, framing: framing),
            ],
          );
        },
      ),
    );
  }
}

/// Collapsed by default: method, model and demo-data notice.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.result, required this.framing});

  final RiskResult result;
  final ContributionFraming framing;

  @override
  Widget build(BuildContext context) {
    final method = framing.relativeToPrediction
        ? 'AIOVY uses SHAP (SHapley Additive exPlanations) to show how much each indicator moved the '
            "model's probability for ${result.riskLevel.label}, compared with the model's average. Bars to the "
            'right supported this level; bars to the left counted against it. The values are in probability '
            'units, so a value of +0.10 moved the probability up by about 10 percentage points.'
        : 'This explanation shows how much each indicator moved a prototype risk score toward higher or lower '
            'risk. Longer bars mean a stronger influence.';
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.onSurfaceVariant,
          leading: const IconTile(icon: Icons.info_outline, size: 36, iconSize: 18, radius: 10),
          title: Text('About this explanation', style: AppTextStyles.labelLg),
          subtitle: Text(
            'Method, model and data',
            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          children: [
            Text(method, style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.model_training, size: 17, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text('Model: ${result.modelName}', style: AppTextStyles.labelMd)),
              ],
            ),
            if (result.isDemo) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.science_outlined, size: 17, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo values from the prototype classifier, pending thesis evaluation. '
                      'Not trained-model SHAP output.',
                      style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            LinkButton(
              label: 'How AIOVY Works',
              trailingIcon: Icons.chevron_right,
              onPressed: () => AppNavigator.push(context, const ResearchScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
