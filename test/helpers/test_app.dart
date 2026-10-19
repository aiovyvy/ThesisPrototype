import 'dart:convert';
import 'dart:io';

import 'package:aiovy/core/theme/app_theme.dart';
import 'package:aiovy/data/mock/mock_clinician.dart';
import 'package:aiovy/data/repositories/app_settings.dart';
import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/maternal_indicators.dart';
import 'package:aiovy/models/risk_level.dart';
import 'package:aiovy/models/risk_result.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/services/mock_risk_classifier.dart';
import 'package:aiovy/services/risk_classifier.dart';
import 'package:aiovy/state/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wraps [home] in the app's theme and [AppScope], like [AiovyApp] does.
Widget testApp(
  Widget home, {
  PatientRepository? repository,
  AppSettings? settings,
  RiskClassifier? classifier,
  Key? boundaryKey,
}) {
  final app = AppScope(
    repository: repository ?? PatientRepository(),
    settings: settings ?? AppSettings(),
    classifier: classifier ?? const MockRiskClassifier(latency: Duration.zero),
    clinician: MockClinician.demo,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: AppNavigator.messengerKey,
      home: home,
    ),
  );
  return boundaryKey == null ? app : RepaintBoundary(key: boundaryKey, child: app);
}

/// Sets the logical screen size (and text scale) for the current test.
void setScreen(WidgetTester tester, Size logical, {double textScale = 1.0, double dpr = 2.0}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = logical * dpr;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Gives tests real fonts without network access.
///
/// google_fonts looks for a bundled `Inter-<Weight>.ttf` asset before it
/// tries the network. This answers the asset channel with such a manifest,
/// backed by the Flutter SDK's own Roboto files, so google_fonts takes its
/// normal bundled-font path (no network, no load errors). The Material Icons
/// font is registered too, so icons render as glyphs in screenshots.
///
/// Roboto is slightly narrower than Inter: layout tests also run with a
/// larger text scale to leave margin for that.
Future<void> loadTestFonts() async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final root = Platform.environment['FLUTTER_ROOT'];
  final dir = root == null ? null : Directory('$root/bin/cache/artifacts/material_fonts');
  Uint8List? read(String file) {
    final f = File('${dir?.path}/$file');
    return dir != null && f.existsSync() ? f.readAsBytesSync() : null;
  }

  final regular = read('roboto-regular.ttf');
  final medium = read('roboto-medium.ttf');
  final bold = read('roboto-bold.ttf');
  if (regular == null || medium == null || bold == null) {
    // No SDK fonts: let google_fonts fail quietly on the network as before.
    GoogleFonts.config.allowRuntimeFetching = true;
    return;
  }
  final fonts = <String, Uint8List>{
    for (final w in ['Thin', 'ExtraLight', 'Light', 'Regular']) 'test_fonts/Inter-$w.ttf': regular,
    for (final w in ['Medium', 'SemiBold']) 'test_fonts/Inter-$w.ttf': medium,
    for (final w in ['Bold', 'ExtraBold', 'Black']) 'test_fonts/Inter-$w.ttf': bold,
  };
  final manifest = const StandardMessageCodec().encodeMessage(<Object?, Object?>{
    for (final k in fonts.keys)
      k: [
        {'asset': k},
      ],
  });

  binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
    if (key == 'AssetManifest.bin') return manifest;
    final bytes = fonts[key];
    return bytes == null ? null : ByteData.sublistView(bytes);
  });

  final icons = read('materialicons-regular.otf');
  if (icons != null) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons)))).load();
  }
}

/// The request/response example documented in `ml_model/uci/api/README.md`
/// (a real `/classify` response), used to render trained-model output.
const apiExampleIndicators = MaternalIndicators(
  age: 32,
  systolic: 142,
  diastolic: 92,
  bloodGlucose: 5.6,
  bodyTempF: 98.4,
  heartRate: 82,
);

final RiskResult apiExampleResult = RiskResult(
  riskLevel: RiskLevel.high,
  probabilities: const {RiskLevel.low: 0.0819, RiskLevel.moderate: 0.2695, RiskLevel.high: 0.6486},
  modelName: 'Random Forest (UCI)',
  featureContributions: [
    for (final e in const {
      Indicator.systolic: 0.4376,
      Indicator.bloodGlucose: -0.1484,
      Indicator.age: 0.0352,
      Indicator.heartRate: 0.0188,
      Indicator.diastolic: -0.0167,
      Indicator.bodyTemperature: -0.0121,
    }.entries)
      FeatureContribution(indicator: e.key, value: e.value),
  ],
  isDemo: false,
);

/// A trained-model stand-in: returns [result] (or throws [errors] first, one
/// per call) without any network access.
class FakeApiClassifier implements RiskClassifier {
  FakeApiClassifier({RiskResult? result, List<Object>? errors})
      : _result = result ?? apiExampleResult,
        _errors = List.of(errors ?? const []);

  final RiskResult _result;
  final List<Object> _errors;
  int calls = 0;

  @override
  String get modelName => 'Random Forest (UCI)';

  @override
  bool get isDemo => false;

  @override
  Future<RiskResult> classify(MaternalIndicators indicators) async {
    calls++;
    if (_errors.isNotEmpty) throw _errors.removeAt(0);
    return _result;
  }
}
