import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/maternal_indicators.dart';
import '../models/risk_level.dart';
import '../models/risk_result.dart';

/// How to read the sign of a [FeatureContribution] for one result.
///
/// The two classifiers return contributions with different meanings:
///
/// * the trained model (`ApiRiskClassifier`) returns SHAP values **for the
///   predicted class** – positive supports the predicted level, negative
///   counts against it, whichever level that is;
/// * the demo heuristic (`MockRiskClassifier`, `isDemo == true`) returns
///   scores where positive always means "toward higher risk".
///
/// Labelling every positive value "raises risk" is therefore wrong for a
/// trained-model Low Risk result. All explanation copy goes through this
/// class so the wording always matches the numbers.
@immutable
class ContributionFraming {
  const ContributionFraming._({required this.level, required this.relativeToPrediction});

  factory ContributionFraming.of(RiskResult r) =>
      ContributionFraming._(level: r.riskLevel, relativeToPrediction: !r.isDemo);

  /// The predicted level the values are relative to.
  final RiskLevel level;

  /// True for trained-model SHAP values (relative to [level]).
  final bool relativeToPrediction;

  /// Legend / axis label for positive values.
  String get positiveLabel => relativeToPrediction ? 'Supports ${level.label}' : 'Toward higher risk';

  /// Legend / axis label for negative values.
  String get negativeLabel => relativeToPrediction ? 'Against ${level.label}' : 'Toward lower risk';

  /// Direction uses the actual sign, without arbitrary strength cutoffs.
  String describe(double v) {
    if (v == 0) return 'No contribution';
    if (relativeToPrediction) {
      return '${v > 0 ? 'Supports' : 'Opposes'} ${level.label}';
    }
    return v > 0 ? 'Toward higher risk' : 'Toward lower risk';
  }

  /// Deterministic summary of the largest contribution in each direction.
  /// Sorting here also covers callers passing unsorted historical results.
  String summary(List<FeatureContribution> contributions, {String Function(Indicator)? valueText}) {
    final ranked = rankedContributions(contributions);
    final pos = ranked.where((f) => f.value > 0);
    final neg = ranked.where((f) => f.value < 0);
    String detail(FeatureContribution f) =>
        '${f.indicator.longLabel}${valueText == null ? '' : ' (${valueText(f.indicator)})'} '
        '[${Fmt.contribution(f.value)}]';
    if (ranked.isEmpty) return 'No contributions were returned for this assessment.';
    if (pos.isEmpty && neg.isEmpty) {
      return 'All returned contributions are zero. No indicator moved the model output away from its baseline.';
    }
    final first = pos.isEmpty
        ? (relativeToPrediction
            ? 'No indicator had a positive contribution supporting ${level.label}.'
            : 'No indicator pushed toward higher risk.')
        : '${detail(pos.first)} ${relativeToPrediction ? 'provided the largest support for ${level.label}' : 'pushed most toward higher risk'}'
            '${pos.length > 1 && pos.elementAt(1).value == pos.first.value ? ' (tied)' : ''}.';
    if (neg.isEmpty) return '$first No indicator had a negative contribution.';
    return '$first ${detail(neg.first)} '
        '${relativeToPrediction ? 'provided the largest opposing contribution to ${level.label}' : 'pushed most toward lower risk'}'
        '${neg.length > 1 && neg.elementAt(1).value == neg.first.value ? ' (tied)' : ''}.';
  }
}

/// Small colour swatch + label used above contribution charts.
class ContributionLegend extends StatelessWidget {
  const ContributionLegend({super.key, required this.framing});

  final ContributionFraming framing;

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 8,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ],
        );
    return ExcludeSemantics(
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          item(AppColors.shapNegative, framing.negativeLabel),
          item(AppColors.shapPositive, framing.positiveLabel),
        ],
      ),
    );
  }
}

/// One indicator's contribution as a diverging bar: negative values grow
/// left from the centre line, positive values grow right. Bar length is
/// relative to the largest absolute value in the result.
class ContributionBar extends StatelessWidget {
  const ContributionBar({
    super.key,
    required this.contribution,
    required this.framing,
    required this.valueText,
    required this.maxAbs,
    this.showDescription = true,
  });

  final FeatureContribution contribution;
  final ContributionFraming framing;

  /// The entered value in the clinician's units, e.g. "142 mmHg".
  final String valueText;
  final double maxAbs;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final v = contribution.value;
    final frac = maxAbs <= 0 ? 0.0 : (v.abs() / maxAbs).clamp(0.0, 1.0).toDouble();
    final description = framing.describe(v);
    final color = v >= 0 ? AppColors.shapPositive : AppColors.shapNegative;

    return Semantics(
      label:
          '${contribution.indicator.longLabel}, $valueText. $description. ${framing.relativeToPrediction ? 'SHAP value' : 'Demo score'} ${Fmt.contribution(v)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(contribution.indicator.longLabel, style: AppTextStyles.labelLg),
              Text(valueText, style: AppTextStyles.labelMd.tabular.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 12,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final half = c.maxWidth / 2;
                      // Nonzero values retain a visible mark; zero has no bar.
                      final len = v == 0 ? 0.0 : (half * frac).clamp(2.0, half).toDouble();
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLow,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          Positioned(
                            left: v >= 0 ? half : half - len,
                            width: len,
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.horizontal(
                                  left: v >= 0 ? Radius.zero : const Radius.circular(99),
                                  right: v >= 0 ? const Radius.circular(99) : Radius.zero,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: half - 0.75,
                            width: 1.5,
                            top: 0,
                            bottom: 0,
                            child: const ColoredBox(color: AppColors.outline),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  Fmt.contribution(v),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.labelSm.tabular.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (showDescription) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTextStyles.labelSm
                  .weight(FontWeight.w500)
                  .copyWith(color: v > 0 ? AppColors.primaryDark : AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Largest absolute first; ties use the canonical indicator order.
List<FeatureContribution> rankedContributions(List<FeatureContribution> contributions) =>
    List<FeatureContribution>.of(contributions)
      ..sort((a, b) {
        final impact = b.value.abs().compareTo(a.value.abs());
        return impact == 0 ? a.indicator.index.compareTo(b.indicator.index) : impact;
      });

/// A zero-only result has a safe scale but no contribution bars.
double contributionScale(List<FeatureContribution> contributions) =>
    contributions.fold<double>(0, (m, f) => f.value.abs() > m ? f.value.abs() : m);

/// Full-width, keyboard-accessible explanation entry point with wrapping text.
class ExplanationButton extends StatelessWidget {
  const ExplanationButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size(48, 72),
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Why did AI predict this?', style: AppTextStyles.labelLg.copyWith(color: AppColors.onPrimary)),
                    const SizedBox(height: 4),
                    Text('See how your six indicators shaped this result',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.onPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      );
}

/// The three class probabilities as labelled horizontal bars. The predicted
/// level is emphasised; the others are shown in neutral grey so colour
/// still means "this is the result".
class ProbabilityBars extends StatelessWidget {
  const ProbabilityBars({super.key, required this.result, this.trackColor = AppColors.surfaceLow});

  final RiskResult result;

  /// Bar background; white when the bars sit on a tinted surface.
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final l in RiskLevel.values) ...[
          if (l != RiskLevel.low) const SizedBox(height: 10),
          _row(context, l, result.probabilities[l] ?? 0, l == result.riskLevel),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, RiskLevel l, double p, bool predicted) {
    final labelStyle = predicted
        ? AppTextStyles.labelLg.copyWith(color: l.textColor)
        : AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant);
    final track = ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
          height: predicted ? 12 : 8,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: trackColor)),
            FractionallySizedBox(
                widthFactor: p.clamp(0.0, 1.0).toDouble(),
                heightFactor: 1,
                child: ColoredBox(color: predicted ? l.color : AppColors.outline.withAlpha(110))),
          ])),
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Semantics(
        label: '${l.label}: ${Fmt.percent(p)}${predicted ? ', predicted' : ''}',
        excludeSemantics: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 4, children: [
            Text(l.shortLabel, style: labelStyle),
            Text(Fmt.percent(p), style: labelStyle.tabular),
          ]),
          const SizedBox(height: 6),
          track,
        ]),
      );
    }
    return Semantics(
      label: '${l.label}: ${Fmt.percent(p)}${predicted ? ', predicted' : ''}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(l.shortLabel, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(child: track),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 44,
            child: Text(
              Fmt.percent(p),
              textAlign: TextAlign.end,
              style: (predicted ? AppTextStyles.labelLg : AppTextStyles.labelMd).tabular.copyWith(
                    color: predicted ? l.textColor : AppColors.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
