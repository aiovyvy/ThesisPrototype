import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/navigation/demo_mode_storage.dart';
import 'package:aiovy/navigation/web_router.dart';
import 'package:aiovy/screens/assessment/assessment_input_screen.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/processing/processing_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/services/risk_classifier.dart';
import 'package:aiovy/widgets/buttons.dart';
import 'package:aiovy/widgets/research_disclaimer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_session_test.dart' show TabStorage;
import 'helpers/test_app.dart';
import 'web_router_test.dart' show routedApp;

const processing = ProcessingScreen(patientId: 'synthetic', indicators: apiExampleIndicators, isNewPatient: true);

void main() {
  setUpAll(loadTestFonts);

  testWidgets('immediate success opens the unchanged result without a minimum wait', (tester) async {
    setScreen(tester, const Size(390, 844));
    final classifier = FakeApiClassifier();
    final started = tester.binding.clock.now();
    await tester.pumpWidget(testApp(processing, classifier: classifier));
    await tester.pumpAndSettle();
    // Navigation must finish well before the former 2.9-second floor.
    expect(tester.binding.clock.now().difference(started), lessThan(const Duration(seconds: 2)));
    expect(find.byType(ResultScreen), findsOneWidget);
    final result = tester.widget<ResultScreen>(find.byType(ResultScreen));
    expect(result.assessment.result, same(apiExampleResult));
    expect(result.assessment.indicators, same(apiExampleIndicators));
    expect(classifier.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow response stays pending without fake backend stages and completes promptly', (tester) async {
    setScreen(tester, const Size(390, 844));
    final classifier = ControlledClassifier();
    await tester.pumpWidget(testApp(processing, classifier: classifier));
    await tester.pump(const Duration(seconds: 12));
    expect(classifier.requests, hasLength(1));
    expect(find.byType(ResultScreen), findsNothing);
    expect(find.byType(ResearchDisclaimer), findsOneWidget);
    expect(find.text('Explaining the result'), findsNothing);
    expect(find.text('Classifying risk level'), findsNothing);
    classifier.requests.single.complete(apiExampleResult);
    await tester.pump();
    await tester.pump(AppMotion.fade);
    await tester.pump();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure is immediate and duplicate Retry callbacks send one new request', (tester) async {
    setScreen(tester, const Size(390, 844));
    final classifier = ControlledClassifier();
    final repo = PatientRepository(seed: const []);
    await tester.pumpWidget(testApp(processing, classifier: classifier, repository: repo));
    classifier.requests.single.completeError(const RiskClassifierException('Connection failed'));
    await tester.pump();
    expect(find.text('Connection failed'), findsOneWidget);
    expect(find.text('Edit values'), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);
    final retry = tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Try again')).onPressed!;
    retry();
    retry(); // Same-frame repeated tap, before the error controls rebuild.
    expect(classifier.requests, hasLength(2));
    expect(classifier.inputs.last, same(apiExampleIndicators));
    await tester.pump();
    expect(find.text('Try again'), findsNothing);
    expect(find.byType(ResearchDisclaimer), findsOneWidget);
    classifier.requests.last.complete(apiExampleResult);
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(repo.byId('synthetic'), isNull); // Success does not automatically save.
  });

  testWidgets('duplicate assessment callbacks open one route and Edit values allows resubmission', (tester) async {
    setScreen(tester, const Size(390, 844));
    final classifier = ControlledClassifier();
    await tester.pumpWidget(testApp(const AssessmentInputScreen(), classifier: classifier));
    for (final (index, value) in ['32', '142', '92', '5.6', '98.4', '82'].indexed) {
      await tester.enterText(find.byType(TextField).at(index), value);
    }
    await tester.pump();
    final submit = tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Assess risk')).onPressed!;
    submit();
    submit();
    await tester.pump();
    await tester.pump(AppMotion.fade);
    expect(find.byType(ProcessingScreen), findsOneWidget);
    expect(classifier.requests, hasLength(1));
    classifier.requests.single.completeError(const RiskClassifierException('Connection failed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit values'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assess risk'));
    await tester.pump();
    expect(classifier.requests, hasLength(2));
    classifier.requests.last.complete(apiExampleResult);
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
  });

  testWidgets('completion during the Back transition cannot reopen Result', (tester) async {
    setScreen(tester, const Size(390, 844));
    final classifier = ControlledClassifier();
    await tester.pumpWidget(testApp(const Scaffold(body: Text('Safe page')), classifier: classifier));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(AppNavigator.fadeRoute(processing));
    await tester.pump();
    await tester.pump(AppMotion.fade);
    navigator.pop();
    classifier.requests.single.complete(apiExampleResult);
    await tester.pumpAndSettle();
    expect(find.text('Safe page'), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout while pending rejects late success and protected history', (tester) async {
    setScreen(tester, const Size(390, 844));
    final classifier = ControlledClassifier();
    final router = WebRouter(demoSession: DemoSession(TabStorage()));
    addTearDown(router.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, PatientRepository(), classifier: classifier));
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!.push(AppNavigator.fadeRoute(processing));
    await tester.pump();
    await tester.pump(AppMotion.fade);
    router.signOut();
    classifier.requests.single.complete(apiExampleResult);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);
    await router.setNewRoutePath('/result');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
