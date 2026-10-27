import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/research_overview.dart';
import '../../models/research.dart';
import '../../navigation/route_session.dart';
import '../../widgets/app_header.dart';
import '../../widgets/common.dart';
import '../../widgets/research_disclaimer.dart';

/// Describes the working prototype; does not run inference or access records.
class ResearchScreen extends StatelessWidget implements RestorableWebPage {
  const ResearchScreen({super.key});

  @override
  String get restorableWebLocation => '/how-aiovy-works';
  @override
  bool get requiresDemoAccess => true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'How AIOVY Works', style: HeaderStyle.backCentered),
      body: SingleChildScrollView(
        padding: AppLayout.page(context, top: AppSpacing.md, bottom: AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ResearchDisclaimer(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    'Use synthetic inputs for assessments and the fixed public research examples for demonstration only.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.md),
                const _InformationCard(
                  title: 'Two separate Random Forest workflows',
                  text: 'The UCI assessment prototype and the experimental Research Demonstration use different saved '
                      'models and independent APIs. Only Random Forest is integrated. Logistic Regression and '
                      'XGBoost appear in offline research comparisons, not as selectable app classifiers.',
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionTitle('From measurements to explanation', icon: Icons.account_tree_outlined),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < ResearchOverview.pipeline.length; i++) ...[
                  _StageCard(stage: ResearchOverview.pipeline[i], number: i + 1),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                const SectionTitle('What the saved evaluations show', icon: Icons.analytics_outlined),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'These scores measure agreement with supplied dataset labels, not clinically verified outcomes. '
                  'Different datasets and test splits mean the scores do not establish that one model is better.',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final model in ResearchOverview.models) ...[
                  _ModelCard(model: model),
                  const SizedBox(height: AppSpacing.md),
                ],
                const _InformationCard(
                  title: 'Reading the scores',
                  text: 'Accuracy is the share of test records whose predicted category matches the dataset label. '
                      'Macro F1 balances precision and recall, giving each category equal weight. '
                      'High-risk recall is the share of high-risk-labelled test records predicted as high risk. '
                      'None of these scores establishes clinical safety.',
                ),
                const SizedBox(height: AppSpacing.sm),
                const _InformationCard(
                  title: 'Why Random Forest?',
                  text: 'The saved UCI comparison selected Random Forest by mean high-risk recall across repeated '
                      'nested cross-validation, with macro F1 as a tie-break. The scores above come from the separate '
                      'locked test, not those cross-validation folds. Selection under that rule does not mean '
                      'Random Forest is best on every metric or clinically validated.',
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionTitle('Understanding SHAP', icon: Icons.insights_outlined),
                const SizedBox(height: AppSpacing.sm),
                const _InformationCard(
                  title: 'What moved this model prediction?',
                  text: 'SHAP assigns a contribution to each input for the predicted category. Positive contributions '
                      'raise that category’s probability from the model’s baseline; negative contributions lower it. '
                      'The baseline plus all six contributions reconstructs the predicted probability, checked by the APIs. '
                      'A probability is a model output, not a verified chance of a medical outcome. '
                      'SHAP explains model behavior, not medical causation. It does not show that changing a measurement '
                      'will improve health or recommend treatment.',
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionTitle('Evidence and limitations', icon: Icons.menu_book_outlined),
                const SizedBox(height: AppSpacing.sm),
                const InfoNote(
                  title: 'Units and labels still need verification',
                  text: 'The Hossain source uses conflicting glucose-unit labels. The research service provisionally '
                      'treats values as mmol/L without converting glucose, and converts temperature from °F to °C. '
                      'A corrected source dictionary and original unit history are missing. '
                      'UCI label provenance is undocumented; Hossain label rules and expert adjudication are not '
                      'fully reproducible locally. Neither model has established clinical validity.',
                  icon: Icons.info_outline,
                  circleIcon: false,
                  background: AppColors.surfaceContainer,
                ),
                const SizedBox(height: AppSpacing.sm),
                const _InformationCard(
                  title: 'Sources behind this prototype',
                  text: 'UCI Maternal Health Risk dataset; local final evaluation from notebook 03 '
                      '(451 processed records). Hossain, M. M. (2025), Maternal health risk data, '
                      'Mendeley Data V1, DOI: 10.17632/ckhgtgdg4f.1; supporting Hossain et al. publication '
                      '(2026), DOI: 10.1186/s12911-026-03343-1; local evaluation from notebook 04. '
                      'SHAP: Lundberg and Lee (2017), A Unified Approach to Interpreting Model Predictions. '
                      'Full artifact paths, citations and source limitations are documented in the project README.',
                ),
                const SizedBox(height: AppSpacing.sm),
                const VersionFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleMd),
            const SizedBox(height: AppSpacing.sm),
            Text(text, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant, height: 1.45)),
          ],
        ),
      );
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.number});

  final PipelineStage stage;
  final int number;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(stage.icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$number. ${stage.title}', style: AppTextStyles.labelLg),
                  const SizedBox(height: AppSpacing.xs),
                  Text(stage.description, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});

  final ModelInfo model;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.name, style: AppTextStyles.titleMd),
            const SizedBox(height: AppSpacing.xs),
            Text(model.subtitle, style: AppTextStyles.labelMd.copyWith(color: AppColors.primary)),
            const SizedBox(height: AppSpacing.sm),
            Text(model.description, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            Text(model.evaluation, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            ResponsiveGrid(
              columns: 3,
              minItemWidth: 140,
              spacing: AppSpacing.sm,
              children: [
                for (final metric in model.metrics.entries)
                  Semantics(
                    label: '${model.name}, ${metric.key}: ${metric.value}, agreement with dataset labels',
                    excludeSemantics: true,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        children: [
                          Text(metric.key, style: AppTextStyles.labelSm, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.xs),
                          Text(metric.value, style: AppTextStyles.titleMd.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
