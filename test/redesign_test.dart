import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/models/maternal_indicators.dart';
import 'package:aiovy/models/risk_level.dart';
import 'package:aiovy/models/risk_result.dart';
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
import 'package:aiovy/widgets/explanation_widgets.dart';
import 'package:aiovy/widgets/patient_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

/// Test fixture only (not shown in the app): a trained-model style result
/// predicting Low, to check the wording is relative to the predicted level.
RiskResult _apiLow() => RiskResult(
      riskLevel: RiskLevel.low,
      probabilities: const {RiskLevel.low: 0.7, RiskLevel.moderate: 0.27, RiskLevel.high: 0.03},
      modelName: 'Random Forest (UCI)',
      featureContributions: const [
        FeatureContribution(indicator: Indicator.systolic, value: 0.2),
        FeatureContribution(indicator: Indicator.bloodGlucose, value: -0.08),
        FeatureContribution(indicator: Indicator.age, value: 0.01),
      ],
      isDemo: false,
    );

void main() {
  setUpAll(loadTestFonts);
  setUp(() => AppNavigator.currentTab.value = ShellTab.home);

  group('ContributionFraming', () {
    test('trained-model values are relative to the predicted level', () {
      final f = ContributionFraming.of(_apiLow());
      expect(f.positiveLabel, 'Supports Low Risk');
      expect(f.negativeLabel, 'Against Low Risk');
      // A positive value for a Low prediction supports Low – it does not
      // "raise risk".
      expect(f.describe(0.2), 'Moderately supports Low Risk');
      expect(f.describe(-0.08), 'Slightly against Low Risk');
      expect(f.describe(0.01), 'Little effect on this result');
      expect(
        f.summary(_apiLow().featureContributions),
        'Systolic Blood Pressure was the strongest support for Low Risk. Blood Glucose counted most against it.',
      );
    });

    test('the documented API example reads as support for High Risk', () {
      final f = ContributionFraming.of(apiExampleResult);
      expect(f.positiveLabel, 'Supports High Risk');
      expect(f.describe(0.4376), 'Strongly supports High Risk');
    });

    test('demo heuristic values keep their toward-higher-risk meaning', () {
      final demo = RiskResult(
        riskLevel: RiskLevel.low,
        probabilities: const {RiskLevel.low: 0.6, RiskLevel.moderate: 0.3, RiskLevel.high: 0.1},
        modelName: 'demo',
        featureContributions: const [FeatureContribution(indicator: Indicator.age, value: 0.1)],
        isDemo: true,
      );
      final f = ContributionFraming.of(demo);
      expect(f.positiveLabel, 'Toward higher risk');
      expect(f.describe(0.1), 'Slightly toward higher risk');
      expect(f.summary(demo.featureContributions), 'Maternal Age pushed most toward higher risk.');
    });
  });

  group('Assessment form', () {
    testWidgets('submitting empty highlights every value', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const AssessmentInputScreen()));
      await tester.tap(find.text('Assess risk'));
      await tester.pumpAndSettle();
      expect(find.text('Check the highlighted values'), findsOneWidget);
      expect(find.textContaining('Required · enter'), findsNWidgets(6));
      expect(find.byType(ProcessingScreen), findsNothing);
    });

    testWidgets('diastolic must be lower than systolic', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const AssessmentInputScreen()));
      await tester.enterText(find.byType(TextField).at(1), '90');
      await tester.enterText(find.byType(TextField).at(2), '95');
      await tester.pump();
      expect(find.text('Must be lower than systolic'), findsOneWidget);
    });

    testWidgets('a full assessment can be classified and saved', (tester) async {
      setScreen(tester, const Size(360, 780));
      final repo = PatientRepository();
      final id = repo.nextPatientId();
      final classifier = FakeApiClassifier();
      await tester.pumpWidget(testApp(const AssessmentInputScreen(), repository: repo, classifier: classifier));

      for (final (i, v) in const [(0, '32'), (1, '142'), (2, '92'), (3, '5.6'), (4, '98.4'), (5, '82')]) {
        await tester.enterText(find.byType(TextField).at(i), v);
      }
      await tester.pump();
      expect(find.text('Ready to assess'), findsOneWidget);

      await tester.tap(find.text('Assess risk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50)); // first frame of a push is offstage
      expect(find.byType(ProcessingScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(classifier.calls, 1);
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.text('High Risk'), findsOneWidget);
      expect(find.text('Supports High Risk'), findsOneWidget);
      expect(find.text('Demo output · Pending thesis evaluation'), findsNothing);

      await tester.ensureVisible(find.text('Save to patient record'));
      await tester.tap(find.text('Save to patient record'));
      await tester.pumpAndSettle();
      expect(repo.byId(id)?.latest?.result.riskLevel, RiskLevel.high);
      expect(find.byType(PatientProfileScreen), findsOneWidget);
    });
  });

  testWidgets('a classifier failure shows the reason and can be retried', (tester) async {
    setScreen(tester, const Size(360, 780));
    final classifier = FakeApiClassifier(errors: [const RiskClassifierException('Could not reach the server.')]);
    await tester.pumpWidget(
      testApp(
        const ProcessingScreen(patientId: 'P-0099', indicators: apiExampleIndicators, isNewPatient: true),
        classifier: classifier,
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text("Couldn't get a risk result"), findsOneWidget);
    expect(find.text('Could not reach the server.'), findsOneWidget);
    expect(find.text('Edit values'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(classifier.calls, 2);
    expect(find.byType(ResultScreen), findsOneWidget);
  });

  testWidgets('processing only claims "demo classifier" for the demo', (tester) async {
    setScreen(tester, const Size(360, 780));
    await tester.pumpWidget(
      testApp(
        const ProcessingScreen(patientId: 'P-0099', indicators: apiExampleIndicators, isNewPatient: true),
        classifier: FakeApiClassifier(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Demo classifier'), findsNothing);
    expect(find.text('Model: Random Forest (UCI)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('history shows the glucose unit intact', (tester) async {
    setScreen(tester, const Size(360, 780));
    await tester.pumpWidget(testApp(const PatientProfileScreen(patientId: 'P-0014')));
    await tester.pumpAndSettle();
    // Each value is kept on one line (non-breaking space, word joiner after
    // "/"), and no escape code leaks into the visible text.
    expect(find.textContaining(keepTogether('BG 5.6 mmol/L')), findsOneWidget);
    final nbsp = String.fromCharCode(0xA0), joiner = String.fromCharCode(0x2060);
    expect(keepTogether('BG 5.6 mmol/L'), 'BG${nbsp}5.6${nbsp}mmol/${joiner}L');
    expect(find.textContaining('2060'), findsNothing);
  });

  group('Small screens and large text do not overflow', () {
    final repo = PatientRepository();
    final unsaved = Assessment(
      id: 'A-layout',
      patientId: 'P-0099',
      timestamp: DateTime(2026, 10, 2, 10, 48),
      indicators: apiExampleIndicators,
      result: apiExampleResult,
      assessedBy: 'Demo Clinician',
    );
    final screens = <String, Widget Function()>{
      'splash': () => const SplashScreen(),
      'login': () => const LoginScreen(),
      'home': () => const MainShell(),
      'assessment': () => const AssessmentInputScreen(),
      'assessment prefilled': () => const AssessmentInputScreen(patientId: 'P-0014'),
      'result (model)': () => ResultScreen(assessment: unsaved),
      'result (demo, saved)': () => ResultScreen(assessment: repo.byId('P-0010')!.latest!),
      'explanation': () => ShapScreen(assessment: unsaved),
      'patient profile': () => const PatientProfileScreen(patientId: 'P-0014'),
      'settings': () => const SettingsScreen(),
    };
    for (final (size, scale) in const [(Size(320, 568), 1.3), (Size(360, 640), 1.0), (Size(360, 640), 1.5)]) {
      for (final e in screens.entries) {
        testWidgets('${e.key} at ${size.width.toInt()}x${size.height.toInt()} text x$scale', (tester) async {
          setScreen(tester, size, textScale: scale);
          await tester.pumpWidget(testApp(e.value(), repository: repo));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
