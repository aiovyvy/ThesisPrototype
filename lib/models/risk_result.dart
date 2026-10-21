import 'package:flutter/foundation.dart';

import 'maternal_indicators.dart';
import 'risk_level.dart';

/// One contribution. API SHAP values are relative to the predicted class;
/// demo heuristic scores instead point toward higher/lower risk.
@immutable
class FeatureContribution {
  const FeatureContribution({required this.indicator, required this.value});

  final Indicator indicator;
  final double value;
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
