import '../models/maternal_indicators.dart';
import '../models/risk_result.dart';

/// The single seam between the UI and the machine-learning system.
///
/// Today the app uses [MockRiskClassifier]. When the trained model (or a
/// Python/FastAPI backend) is ready, implement this interface – see
/// `api_risk_classifier.dart` – and swap it in `main.dart`. No screen needs
/// to change.
abstract class RiskClassifier {
  /// Human-readable name shown on the result screen.
  String get modelName;

  Future<RiskResult> classify(MaternalIndicators indicators);
}
