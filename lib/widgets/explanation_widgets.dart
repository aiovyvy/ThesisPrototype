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

  /// Plain-language strength and direction of one value.
  String describe(double v) {
    final a = v.abs();
    if (a < 0.05) return 'Little effect on this result';
    final strength = a >= 0.3 ? 'Strongly' : (a >= 0.15 ? 'Moderately' : 'Slightly');
    if (relativeToPrediction) {
      return '$strength ${v > 0 ? 'supports' : 'against'} ${level.label}';
    }
    return '$strength ${v > 0 ? 'toward higher' : 'toward lower'} risk';
  }

  /// One or two sentences naming the indicators that mattered most.
  String summary(List<FeatureContribution> contributions) {
    String names(Iterable<FeatureContribution> fs) => fs.map((f) => f.indicator.longLabel).join(' and ');
    final pos = contributions.where((f) => f.value >= 0.05).take(2);
    final neg = contributions.where((f) => f.value <= -0.05).take(1);

    final String first;
    if (relativeToPrediction) {
      first = pos.isEmpty
          ? 'No single indicator strongly supported the ${level.label} result.'
          : '${names(pos)} ${pos.length > 1 ? 'were' : 'was'} the strongest support for ${level.label}.';
    } else {
      first = pos.isEmpty
          ? 'No indicator strongly pushed toward higher risk for this assessment.'
          : '${names(pos)} pushed most toward higher risk.';
    }
    if (neg.isEmpty) return first;
    final second = relativeToPrediction
        ? '${names(neg)} counted most against it.'
        : '${names(neg)} pulled most toward lower risk.';
    return '$first $second';
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
    final strong = v.abs() >= 0.05;

    return Semantics(
      label: '${contribution.indicator.longLabel}, $valueText. $description. SHAP value ${Fmt.signed(v)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(contribution.indicator.longLabel, style: AppTextStyles.labelLg)),
              const SizedBox(width: 8),
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
                      // Even a near-zero value shows a sliver, so every row has
                      // a visible mark next to the axis.
                      final len = (half * frac).clamp(2.0, half).toDouble();
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
              SizedBox(
                width: 48,
                child: Text(
                  Fmt.signed(v),
                  textAlign: TextAlign.end,
                  style: AppTextStyles.labelSm.tabular.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          // "Little effect" rows need no sentence; the bar and value say it.
          if (showDescription && strong) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: AppTextStyles.labelSm
                  .weight(FontWeight.w500)
                  .copyWith(color: strong && v > 0 ? AppColors.primary : AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Largest absolute contribution, with a floor so a result whose values are
/// all tiny doesn't render them as full-length bars.
double contributionScale(List<FeatureContribution> contributions) =>
    contributions.fold<double>(0.1, (m, f) => f.value.abs() > m ? f.value.abs() : m);

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
          _row(l, result.probabilities[l] ?? 0, l == result.riskLevel),
        ],
      ],
    );
  }

  Widget _row(RiskLevel l, double p, bool predicted) {
    final labelStyle = predicted
        ? AppTextStyles.labelLg.copyWith(color: l.textColor)
        : AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant);
    return Semantics(
      label: '${l.label}: ${Fmt.percent(p)}${predicted ? ', predicted' : ''}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(l.shortLabel, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: predicted ? 12 : 8,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: trackColor)),
                    FractionallySizedBox(
                      widthFactor: p.clamp(0.0, 1.0).toDouble(),
                      heightFactor: 1,
                      child: ColoredBox(color: predicted ? l.color : AppColors.outline.withAlpha(110)),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
