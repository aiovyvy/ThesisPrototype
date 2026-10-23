import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Independent of RiskClassifier and patient/assessment models by design.
class ResearchDemoClient {
  ResearchDemoClient({Uri? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl(),
        _client = client ?? http.Client();

  static const modelId = 'hossain_6039_rf_experimental_v1';
  static const exampleIds = ['R1', 'R2', 'R3', 'R4', 'R5', 'R6'];
  final Uri baseUrl;
  final http.Client _client;
  static Uri defaultBaseUrl() {
    const configured = String.fromEnvironment('RESEARCH_API_URL');
    return Uri.parse(configured.isNotEmpty ? configured : (kIsWeb ? 'http://127.0.0.1:8001' : 'http://10.0.2.2:8001'));
  }

  Future<ResearchExample> load(String id) async {
    if (!exampleIds.contains(id)) throw ArgumentError('Unknown fixed example');
    final http.Response response;
    try {
      response = await _client.get(baseUrl.resolve('/research/examples/$id')).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw ResearchConnectionException('The research backend at $baseUrl did not respond within 10 seconds. '
          'Check /health and that port 8001 is reachable, then Retry.');
    } on http.ClientException {
      throw ResearchConnectionException('Could not connect to the research backend at $baseUrl. '
          'Check that it is running, /health responds, and the browser origin is allowed by CORS. Then Retry.');
    }
    if (response.statusCode != 200) {
      throw ResearchConnectionException('Research backend at $baseUrl returned HTTP ${response.statusCode}. '
          'Check the backend terminal and /health, then Retry.');
    }
    return ResearchExample.parse(jsonDecode(response.body), expectedId: id);
  }

  void close() => _client.close();
}

class ResearchConnectionException implements Exception {
  const ResearchConnectionException(this.message);
  final String message;
}

class ResearchExample {
  ResearchExample._(this.id, this.datasetLabel, this.prediction, this.probabilities, this.inputs, this.temperatureF,
      this.baseValue, this.contributions);

  static const classes = ['high risk', 'low risk', 'mid risk'];
  static const features = [
    'age',
    'systolic_bp',
    'diastolic_bp',
    'blood_glucose_mmol_l',
    'body_temperature_c',
    'heart_rate'
  ];
  final String id;
  final String datasetLabel;
  final String prediction;
  final Map<String, double> probabilities;
  final Map<String, double> inputs;
  final double temperatureF;
  final double baseValue;
  final Map<String, double> contributions;

  static ResearchExample parse(Object? value, {required String expectedId}) {
    if (value is! Map<String, dynamic> ||
        value['model_id'] != ResearchDemoClient.modelId ||
        value['model_label'] != 'Experimental research model' ||
        value['example_id'] != expectedId ||
        value['split'] != 'held-out' ||
        !classes.contains(value['dataset_label']) ||
        !classes.contains(value['prediction'])) {
      throw const FormatException('Unexpected research model or example');
    }
    final prediction = value['prediction'] as String;
    final probabilities = _numbers(value['probabilities'], classes);
    final inputs = _numbers(value['model_inputs'], features);
    final shap = value['shap'];
    final measurements = value['measurements'];
    final units = value['feature_units'];
    if (shap is! Map<String, dynamic> ||
        shap['explained_class'] != prediction ||
        measurements is! Map<String, dynamic> ||
        units is! Map<String, dynamic> ||
        units['blood_glucose_mmol_l'] != 'provisionally mmol/L' ||
        units['body_temperature_c'] != 'Celsius') {
      throw const FormatException('Unexpected research explanation or units');
    }
    final contributions = _numbers(shap['contributions'], features);
    final base = _number(shap['base_value']);
    final temperatureF = _number(measurements['temperature_f']);
    final reconstructed = base + contributions.values.fold(0.0, (a, b) => a + b);
    final sum = probabilities.values.fold(0.0, (a, b) => a + b);
    if (probabilities.values.any((p) => p < 0 || p > 1) ||
        (sum - 1).abs() > 1e-6 ||
        base < 0 ||
        base > 1 ||
        probabilities.values.any((p) => p > probabilities[prediction]! + 1e-9) ||
        (reconstructed - probabilities[prediction]!).abs() > 1e-6 ||
        (_number(shap['reconstructed_probability']) - reconstructed).abs() > 1e-6 ||
        (inputs['body_temperature_c']! - (temperatureF - 32) * 5 / 9).abs() > 1e-9 ||
        inputs['blood_glucose_mmol_l'] != _number(measurements['blood_glucose'])) {
      throw const FormatException('Research probability, unit or SHAP check failed');
    }
    return ResearchExample._(expectedId, value['dataset_label'] as String, prediction, Map.unmodifiable(probabilities),
        Map.unmodifiable(inputs), temperatureF, base, Map.unmodifiable(contributions));
  }

  static double _number(Object? value) {
    if (value is! num || !value.isFinite) {
      throw const FormatException('Invalid research number');
    }
    return value.toDouble();
  }

  static Map<String, double> _numbers(Object? value, List<String> keys) {
    if (value is! Map<String, dynamic> || value.length != keys.length || !keys.every(value.containsKey)) {
      throw const FormatException('Unexpected research features or classes');
    }
    return {for (final key in keys) key: _number(value[key])};
  }
}
