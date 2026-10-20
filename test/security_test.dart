import 'dart:convert';

import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/navigation/main_shell.dart';
import 'package:aiovy/screens/assessment/assessment_input_screen.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/screens/settings/settings_screen.dart';
import 'package:aiovy/services/api_risk_classifier.dart';
import 'package:aiovy/services/mock_risk_classifier.dart';
import 'package:aiovy/services/risk_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/test_app.dart';

Assessment _entered(String patientId, {bool demo = false}) => Assessment(
      id: 'A-$patientId-session',
      patientId: patientId,
      timestamp: DateTime.now(),
      indicators: apiExampleIndicators,
      result: demo ? const MockRiskClassifier().evaluate(apiExampleIndicators) : apiExampleResult,
      assessedBy: 'Demo Clinician',
    );

void main() {
  setUpAll(loadTestFonts);
  setUp(() => AppNavigator.currentTab.value = ShellTab.home);

  group('Session records (in memory only)', () {
    test('clearSession removes what was entered and keeps the synthetic records', () {
      final repo = PatientRepository();
      final seeded = repo.patients.length;
      final p14History = repo.byId('P-0014')!.assessments.length;
      final newId = repo.nextPatientId();

      repo.saveAssessment(_entered(newId));
      repo.saveAssessment(_entered('P-0014'));
      expect(repo.sessionAssessmentCount, 2);
      expect(repo.byId(newId), isNotNull);
      expect(repo.byId('P-0014')!.assessments.length, p14History + 1);

      repo.clearSession();
      expect(repo.sessionAssessmentCount, 0);
      expect(repo.byId(newId), isNull);
      expect(repo.patients.length, seeded);
      expect(repo.byId('P-0014')!.assessments.length, p14History);
    });

    testWidgets('signing out clears the session records', (tester) async {
      setScreen(tester, const Size(360, 780));
      final repo = PatientRepository()..saveAssessment(_entered('P-0014'));
      await tester.pumpWidget(testApp(const MainShell(), repository: repo));
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Sign Out'), 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The 1 assessment entered in this session will be removed'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pumpAndSettle();
      expect(repo.sessionAssessmentCount, 0);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('"Clear Session Records" in Settings really clears them', (tester) async {
      setScreen(tester, const Size(360, 900));
      final repo = PatientRepository()..saveAssessment(_entered('P-0014'));
      await tester.pumpWidget(testApp(const SettingsScreen(), repository: repo));
      expect(find.textContaining('1 entered in this session'), findsOneWidget);

      await tester.tap(find.text('Clear Session Records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear records'));
      await tester.pumpAndSettle();
      expect(repo.sessionAssessmentCount, 0);
      expect(find.text('No assessments entered in this session'), findsOneWidget);
    });
  });

  group('Demo access and synthetic data', () {
    testWidgets('login is labelled DEMO ACCESS', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const LoginScreen()));
      expect(find.text('DEMO ACCESS'), findsOneWidget);
      expect(find.textContaining('There is no real authentication'), findsOneWidget);
    });

    testWidgets('the assessment form says synthetic data only', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(const AssessmentInputScreen()));
      expect(find.textContaining('Synthetic test data only. Do not enter real patient information'), findsOneWidget);
    });
  });

  group('Simulated vs trained-model predictions', () {
    testWidgets('a simulated result says so; a model result does not', (tester) async {
      setScreen(tester, const Size(360, 780));
      await tester.pumpWidget(testApp(ResultScreen(assessment: _entered('P-0099', demo: true))));
      await tester.pumpAndSettle();
      expect(find.text('SIMULATED ESTIMATE'), findsOneWidget);
      expect(find.textContaining('not the trained model'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(testApp(ResultScreen(assessment: _entered('P-0099'))));
      await tester.pumpAndSettle();
      expect(find.text('MODEL ESTIMATE'), findsOneWidget);
      expect(find.text('SIMULATED ESTIMATE'), findsNothing);
      expect(find.textContaining('not the trained model'), findsNothing);
    });

    testWidgets('API mode: simulated seed records are tagged among model results', (tester) async {
      setScreen(tester, const Size(360, 1600));
      final repo = PatientRepository()..saveAssessment(_entered('P-0099'));
      await tester.pumpWidget(testApp(const MainShell(), repository: repo, classifier: FakeApiClassifier()));
      await tester.tap(find.text('Patients').last);
      await tester.pumpAndSettle();
      // Ten seeded (simulated) patients are tagged; the model-scored one is not.
      expect(find.text('Simulated'), findsNWidgets(10));
      expect(find.bySemanticsLabel(RegExp(r'^Patient P-0099.*')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Patient P-0099.*\(simulated\)')), findsNothing);
      expect(find.textContaining('Demo mode'), findsNothing);
    });

    testWidgets('demo mode: one notice instead of a tag on every row', (tester) async {
      setScreen(tester, const Size(360, 1600));
      await tester.pumpWidget(testApp(const MainShell()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo mode: every prediction is simulated'), findsOneWidget);
      expect(find.text('Simulated'), findsNothing);
    });

    testWidgets('Settings states where predictions come from', (tester) async {
      setScreen(tester, const Size(360, 900));
      await tester.pumpWidget(testApp(const SettingsScreen()));
      expect(find.textContaining('Simulated by the built-in demo classifier'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(testApp(const SettingsScreen(), classifier: FakeApiClassifier()));
      expect(find.textContaining('Trained model (Random Forest (UCI)) via the AIOVY API'), findsOneWidget);
    });
  });

  group('API transport', () {
    Map<String, Object> okBody() => {
          'risk_level': 'high',
          'probabilities': {'low': 0.0819, 'moderate': 0.2695, 'high': 0.6486},
          'model_name': 'Random Forest (UCI)',
          'feature_contributions': {
            'Age': 0.0352,
            'SystolicBP': 0.4376,
            'DiastolicBP': -0.0167,
            'BS': -0.1484,
            'BodyTemp': -0.0121,
            'HeartRate': 0.0188,
          },
        };

    test('when HTTPS is required, nothing is sent to an http:// server', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(okBody()), 200);
      });
      final c = ApiRiskClassifier(baseUrl: Uri.parse('http://10.0.2.2:8000'), client: client, requireHttps: true);
      await expectLater(
        c.classify(apiExampleIndicators),
        throwsA(isA<RiskClassifierException>().having((e) => e.message, 'message', contains('Nothing was sent'))),
      );
      expect(calls, 0);
    });

    test('HTTPS servers work when HTTPS is required; contract unchanged', () async {
      Uri? sentTo;
      Map<String, dynamic>? sentBody;
      final client = MockClient((req) async {
        sentTo = req.url;
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(okBody()), 200);
      });
      final c = ApiRiskClassifier(baseUrl: Uri.parse('https://aiovy.example'), client: client, requireHttps: true);
      final r = await c.classify(apiExampleIndicators);
      expect(sentTo.toString(), 'https://aiovy.example/classify');
      expect(sentBody, {'Age': 32, 'SystolicBP': 142, 'DiastolicBP': 92, 'BS': 5.6, 'BodyTemp': 98.4, 'HeartRate': 82});
      expect(r.isDemo, isFalse);
      expect(r.probabilities.values.reduce((a, b) => a + b), closeTo(1, 1e-3));
    });

    test('debug builds still reach the local http:// development server', () async {
      final client = MockClient((_) async => http.Response(jsonEncode(okBody()), 200));
      final c = ApiRiskClassifier(baseUrl: Uri.parse('http://10.0.2.2:8000'), client: client, requireHttps: false);
      expect((await c.classify(apiExampleIndicators)).modelName, 'Random Forest (UCI)');
    });

    test('in tests (not a release build) HTTPS is not required by default', () {
      expect(ApiRiskClassifier(baseUrl: Uri.parse('http://localhost:8000')).requireHttps, isFalse);
    });
  });
}
