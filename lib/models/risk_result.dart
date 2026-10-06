import 'package:flutter/foundation.dart';

import 'maternal_indicators.dart';
import 'risk_level.dart';

/// One SHAP-style contribution. Positive pushes toward higher risk,
/// negative pulls toward the baseline (lower risk).
@immutable
class FeatureContribution {
  const FeatureContribution({required this.indicator, required this.value});

  final Indicator indicator;
  final double value;

  String get explanation {
    final v = value;
    if (v >= 0.3) return 'Strong positive contribution to elevated risk';
    if (v >= 0.15) return 'Moderate positive risk attribution';
    if (v >= 0.05) return 'Slight positive risk attribution';
    if (v > -0.05) return 'Minimal attribution near neutral';
    if (v > -0.15) return 'Slightly pulling toward baseline risk';
    return 'Pulling toward baseline (lower) risk';
  }
}

/// What a classifier returns. This is the contract the real ML/API
/// classifier must fulfil later: riskLevel, probabilities, modelName,
/// featureContributions.
@immutable
class RiskResult {
  const RiskResult({
    required this.riskLevel,
    required this.probabilities,
    required this.modelName,
    required this.featureContributions,
    this.isDemo = true,
  });

  final RiskLevel riskLevel;

  /// Class probabilities summing to 1.
  final Map<RiskLevel, double> probabilities;
  final String modelName;

  /// Sorted by absolute impact, largest first.
  final List<FeatureContribution> featureContributions;

  /// True while values come from [MockRiskClassifier].
  final bool isDemo;
}
