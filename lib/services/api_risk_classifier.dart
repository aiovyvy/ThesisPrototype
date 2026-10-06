import '../models/maternal_indicators.dart';
import '../models/risk_result.dart';
import 'risk_classifier.dart';

/// Placeholder for the real classifier (not used yet).
///
/// Suggested backend contract (e.g. FastAPI serving the selected model and
/// computing SHAP with `shap.TreeExplainer` / `LinearExplainer`):
///
/// POST /classify
/// request:  {"Age": 32, "SystolicBP": 142, "DiastolicBP": 92,
///            "BS": 5.6, "BodyTemp": 98.4, "HeartRate": 82}
/// response: {"risk_level": "moderate",
///            "probabilities": {"low": 0.12, "moderate": 0.71, "high": 0.17},
///            "model_name": "XGBoost",
///            "feature_contributions": {"SystolicBP": 0.38, "BS": 0.02, ...}}
///
/// To use it: add the `http` package, implement [classify], then in
/// `main.dart` replace `MockRiskClassifier()` with `ApiRiskClassifier(...)`.
class ApiRiskClassifier implements RiskClassifier {
  ApiRiskClassifier({required this.baseUrl});

  final Uri baseUrl;

  @override
  String get modelName => 'Selected Model';

  @override
  Future<RiskResult> classify(MaternalIndicators indicators) {
    // final body = jsonEncode(indicators.toFeatureMap());
    // final res = await http.post(baseUrl.resolve('/classify'), body: body, ...);
    // return _parse(jsonDecode(res.body));
    throw UnimplementedError('Connect the trained model API here.');
  }
}
