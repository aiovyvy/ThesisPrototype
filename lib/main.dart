import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/mock/mock_clinician.dart';
import 'data/repositories/app_settings.dart';
import 'data/repositories/patient_repository.dart';
import 'services/mock_risk_classifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF9F9F8),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(AiovyApp(
    repository: PatientRepository(),
    settings: AppSettings(),
    // ▼ Swap this for ApiRiskClassifier(...) when the trained model is ready.
    classifier: const MockRiskClassifier(),
    clinician: MockClinician.demo,
  ));
}
