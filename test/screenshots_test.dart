// Renders the main screens to PNG files for visual review. Skipped unless an
// output folder is given:
//
//   flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=<folder>
//
// Text uses the SDK's Roboto in place of Inter (see loadTestFonts).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aiovy/data/repositories/app_settings.dart';
import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/navigation/main_shell.dart';
import 'package:aiovy/screens/assessment/assessment_input_screen.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/patient_profile/patient_profile_screen.dart';
import 'package:aiovy/screens/processing/processing_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/screens/settings/settings_screen.dart';
import 'package:aiovy/screens/shap/shap_screen.dart';
import 'package:aiovy/screens/splash/splash_screen.dart';
import 'package:aiovy/services/risk_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/test_app.dart';

const _out = String.fromEnvironment('SCREENSHOTS');
final _boundary = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  final ro = tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final ui.Image img = await ro.toImage(pixelRatio: tester.view.devicePixelRatio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _render(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size size = const Size(360, 780),
  PatientRepository? repository,
  RiskClassifier? classifier,
  AppSettings? settings,
  Future<void> Function()? interact,
  bool settle = true,
}) async {
  setScreen(tester, size);
  AppNavigator.currentTab.value = ShellTab.home;
  // Unmount the previous app so its Navigator (and any pushed routes) go.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    testApp(screen, repository: repository, classifier: classifier, settings: settings, boundaryKey: _boundary),
  );
  // Wait for google_fonts to register each weight (async) so no frame uses the
  // test placeholder font.
  await tester.runAsync(GoogleFonts.pendingFonts);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 1800));
  }
  if (interact != null) await interact();
  await _shot(tester, name);
}

void main() {
  setUpAll(loadTestFonts);

  final skip = _out.isEmpty ? 'pass --dart-define=SCREENSHOTS=<folder> to render' : null;
  const tall = Size(360, 1500);

  testWidgets('render screens', skip: skip != null, (tester) async {
    final repo = PatientRepository();
    final p14 = repo.byId('P-0014')!;
    final demoHigh = repo.byId('P-0010')!.latest!;
    final unsavedApi = Assessment(
      id: 'A-screenshot',
      patientId: 'P-0015',
      timestamp: DateTime.now(),
      indicators: apiExampleIndicators,
      result: apiExampleResult,
      assessedBy: 'Demo Clinician',
    );

    await _render(tester, '01_splash', const SplashScreen());
    await _render(tester, '02_login', const LoginScreen());
    await _render(tester, '03_home', const MainShell(), repository: repo, size: tall);
    await _render(tester, '04_assessment_empty', const AssessmentInputScreen(), repository: repo);
    await _render(
      tester,
      '05_assessment_errors',
      const AssessmentInputScreen(),
      repository: repo,
      size: tall,
      interact: () async {
        await tester.enterText(find.byType(TextField).at(1), '90');
        await tester.enterText(find.byType(TextField).at(2), '95');
        await tester.tap(find.text('Assess risk'));
        await tester.pumpAndSettle();
      },
    );
    await _render(tester, '06_assessment_prefilled', AssessmentInputScreen(patientId: p14.id),
        repository: repo, size: tall);
    await _render(
      tester,
      '07_processing',
      const ProcessingScreen(patientId: 'P-0015', indicators: apiExampleIndicators, isNewPatient: true),
      repository: repo,
      settle: false,
    );
    await _render(
      tester,
      '08_processing_error',
      const ProcessingScreen(patientId: 'P-0015', indicators: apiExampleIndicators, isNewPatient: true),
      repository: repo,
      classifier: FakeApiClassifier(
        errors: [
          const RiskClassifierException(
            'Could not reach the risk model server at http://10.0.2.2:8000. '
            'Check that the AIOVY API is running and that this device is on the same network.',
          ),
        ],
      ),
      settle: false,
      interact: () async => tester.pump(const Duration(seconds: 2)),
    );
    await _render(tester, '09_result_api_fold', ResultScreen(assessment: unsavedApi), repository: repo);
    await _render(tester, '10_result_api_full', ResultScreen(assessment: unsavedApi), repository: repo, size: tall);
    await _render(tester, '11_result_demo_saved', ResultScreen(assessment: demoHigh), repository: repo, size: tall);
    await _render(tester, '12_shap_api', ShapScreen(assessment: unsavedApi), repository: repo, size: tall);
    await _render(
      tester,
      '13_patients',
      const MainShell(),
      repository: repo,
      size: tall,
      interact: () async {
        await tester.tap(find.text('Patients').last);
        await tester.pumpAndSettle();
      },
    );
    await _render(tester, '14_profile_p14', PatientProfileScreen(patientId: p14.id), repository: repo, size: tall);
    await _render(
      tester,
      '15_clinician',
      const MainShell(),
      repository: repo,
      size: tall,
      interact: () async {
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
      },
    );
    await _render(tester, '16_settings', const SettingsScreen(), repository: repo, size: tall);
    await _render(tester, '17_home_small', const MainShell(), repository: repo, size: const Size(320, 640));
  });
}
