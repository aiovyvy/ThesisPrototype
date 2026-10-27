import 'dart:convert';
import 'dart:io';

import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/maternal_indicators.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/navigation/demo_mode_storage.dart';
import 'package:aiovy/navigation/web_router.dart';
import 'package:aiovy/screens/assessment/assessment_input_screen.dart';
import 'package:aiovy/screens/patient_profile/patient_profile_screen.dart';
import 'package:aiovy/screens/patients/patients_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/screens/shap/shap_screen.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/services/api_risk_classifier.dart';
import 'package:aiovy/widgets/explanation_widgets.dart';
import 'package:aiovy/widgets/patient_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'demo_session_test.dart' show TabStorage, privateAssessment;
import 'helpers/test_app.dart';
import 'web_router_test.dart' show HistoryRouteProvider, routedApp;

List<Map<String, dynamic>> cases() =>
    (jsonDecode(File('test/fixtures/uci_workflow_responses.json').readAsStringSync())['cases'] as List)
        .cast<Map<String, dynamic>>();

Future<void> enterValues(WidgetTester tester, Map<String, dynamic> values) async {
  for (final (i, key) in ['Age', 'SystolicBP', 'DiastolicBP', 'BS', 'BodyTemp', 'HeartRate'].indexed) {
    await tester.enterText(find.byType(TextField).at(i), '${values[key]}');
  }
  await tester.pump();
}

Future<void> finishClassification(WidgetTester tester) async {
  await tester.tap(find.text('Assess risk'));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  for (final path in ['/assessment', '/patient-details']) {
    testWidgets('$path restoration does not hide blocked-storage or failed-logout warnings', (tester) async {
      final storage = TabStorage()..blocked = true;
      final router = WebRouter(demoSession: DemoSession(storage));
      addTearDown(router.dispose);
      await router.setNewRoutePath(path);
      router.signIn();
      await tester.pumpWidget(routedApp(router, PatientRepository()));
      await tester.pumpAndSettle();
      expect(find.byType(path == '/assessment' ? AssessmentInputScreen : PatientsScreen), findsOneWidget);
      expect(find.text(WebRouter.storageUnavailableNotice), findsOneWidget);
      router.signOut();
      await router.setNewRoutePath(path);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(WebRouter.storageClearFailureNotice), findsOneWidget);
    });
  }

  testWidgets('assessment refresh opens a blank unassociated form without recreating draft or saved records',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final original = PatientRepository()..saveAssessment(privateAssessment());
    final old = WebRouter(demoSession: DemoSession(storage));
    old.signIn();
    await old.setNewRoutePath('/assessment');
    await tester.pumpWidget(routedApp(old, original));
    await tester.pumpAndSettle();
    await enterValues(tester, cases().first['request']);
    await tester.pumpWidget(const SizedBox.shrink());
    old.dispose();
    final fresh = PatientRepository();
    final router = WebRouter(demoSession: DemoSession(storage));
    addTearDown(router.dispose);
    await router.setNewRoutePath('/assessment');
    await tester.pumpWidget(routedApp(router, fresh));
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentInputScreen), findsOneWidget);
    expect(find.text(WebRouter.blankAssessmentNotice), findsOneWidget);
    expect(router.currentConfiguration, '/assessment');
    expect(
        tester.widgetList<TextField>(find.byType(TextField)).every((field) => field.controller!.text.isEmpty), isTrue);
    expect(find.text('Copied from the last visit'), findsNothing);
    expect(fresh.sessionAssessmentCount, 0);
    expect(fresh.byId('private-patient'), isNull);
    expect(storage.entries, {DemoSession.key: DemoSession.marker});
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.currentConfiguration, '/dashboard');
  });

  testWidgets('Patients history navigation keeps available records; refresh has only synthetic seeds', (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final repository = PatientRepository()..saveAssessment(privateAssessment());
    final router = WebRouter(demoSession: DemoSession(storage));
    final provider = HistoryRouteProvider();
    router.signIn();
    provider.incoming('/patients');
    await tester.pumpWidget(routedApp(router, repository, provider: provider));
    await tester.pumpAndSettle();
    expect(find.byType(PatientsScreen), findsOneWidget);
    expect(repository.byId('private-patient'), isNotNull);
    provider.incoming('/dashboard');
    await tester.pumpAndSettle();
    provider.incoming('/patients');
    await tester.pumpAndSettle();
    expect(repository.byId('private-patient'), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    provider.dispose();
    final fresh = PatientRepository();
    final restored = WebRouter(demoSession: DemoSession(storage));
    addTearDown(restored.dispose);
    await restored.setNewRoutePath('/patients');
    await tester.pumpWidget(routedApp(restored, fresh));
    await tester.pumpAndSettle();
    expect(restored.currentConfiguration, '/patients');
    expect(find.byType(PatientsScreen), findsOneWidget);
    expect(fresh.byId('private-patient'), isNull);
    expect(fresh.patients.length, PatientRepository().patients.length);
    await restored.setNewRoutePath('/patient-details');
    await tester.pumpAndSettle();
    expect(restored.currentConfiguration, '/patients');
    expect(find.text(WebRouter.patientUnavailableNotice), findsOneWidget);
    expect(find.byType(PatientProfileScreen), findsNothing);
    restored.navigatorKey.currentState!.push(AppNavigator.route(const PatientProfileScreen(patientId: 'P-0014')));
    await tester.pumpAndSettle();
    expect(find.byType(PatientProfileScreen), findsOneWidget);
    expect(find.text(WebRouter.patientUnavailableNotice), findsNothing);
    expect(fresh.sessionAssessmentCount, 0);
  });

  for (final entry in ['/dashboard', '/patients']) {
    testWidgets('patient opened from $entry publishes its URL and refresh falls back to Patients', (tester) async {
      setScreen(tester, const Size(390, 844));
      final storage = TabStorage();
      final old = WebRouter(demoSession: DemoSession(storage));
      final provider = HistoryRouteProvider()..incoming(entry);
      old.signIn();
      await tester.pumpWidget(routedApp(old, PatientRepository(), provider: provider));
      await tester.pumpAndSettle();
      final row = find.byType(PatientListRow).first;
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(PatientProfileScreen), findsOneWidget);
      expect(provider.value.uri.path, '/patient-details');
      final visibleLocation = provider.value.uri.path;
      await tester.pumpWidget(const SizedBox.shrink());
      old.dispose();
      provider.dispose();
      final fresh = WebRouter(demoSession: DemoSession(storage));
      final freshProvider = HistoryRouteProvider()..incoming(visibleLocation);
      addTearDown(fresh.dispose);
      addTearDown(freshProvider.dispose);
      final repository = PatientRepository();
      await tester.pumpWidget(routedApp(fresh, repository, provider: freshProvider));
      await tester.pumpAndSettle();
      expect(freshProvider.value.uri.path, '/patients');
      expect(find.byType(PatientsScreen), findsOneWidget);
      expect(find.byType(PatientProfileScreen), findsNothing);
      expect(find.text(WebRouter.patientUnavailableNotice), findsOneWidget);
      expect(repository.sessionAssessmentCount, 0);
    });
  }

  for (final item in cases()) {
    final level = item['response']['risk_level'] as String;
    testWidgets('$level UCI response survives create, classify, save, history, SHAP and logout', (tester) async {
      setScreen(tester, const Size(390, 844));
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(request.url.path, '/classify');
        expect(jsonDecode(request.body), item['request']);
        return http.Response(jsonEncode(item['response']), 200);
      });
      final classifier =
          ApiRiskClassifier(baseUrl: Uri.parse('http://uci.test:8000'), client: transport, requireHttps: false);
      addTearDown(transport.close);
      final storage = TabStorage();
      final repository = PatientRepository();
      final id = repository.nextPatientId();
      final router = WebRouter(demoSession: DemoSession(storage), onClearSession: repository.clearSession);
      final provider = HistoryRouteProvider()..incoming('/dashboard');
      addTearDown(router.dispose);
      addTearDown(provider.dispose);
      router.signIn();
      await tester.pumpWidget(routedApp(router, repository, provider: provider, classifier: classifier));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New assessment'));
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, '/assessment');
      await enterValues(tester, item['request']);
      expect(repository.byId(id), isNull); // patient is created only on Save
      await finishClassification(tester);
      expect(provider.value.uri.path, '/result');
      final unsaved = tester.widget<ResultScreen>(find.byType(ResultScreen)).assessment;
      expect(unsaved.result.riskLevel.name, level);
      expect({for (final entry in unsaved.result.probabilities.entries) entry.key.name: entry.value},
          item['response']['probabilities']);
      expect({
        for (final contribution in unsaved.result.featureContributions)
          contribution.indicator.featureKey: contribution.value
      }, item['response']['feature_contributions']);
      expect(repository.sessionAssessmentCount, 0);
      await tester.scrollUntilVisible(find.byType(ExplanationButton), 200,
          scrollable: find.descendant(of: find.byType(ResultScreen), matching: find.byType(Scrollable)).first);
      await Scrollable.ensureVisible(tester.element(find.byType(ExplanationButton)), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExplanationButton));
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, '/explanation');
      expect(tester.widget<ShapScreen>(find.byType(ShapScreen)).assessment, same(unsaved));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, '/result');
      expect(tester.widget<ResultScreen>(find.byType(ResultScreen)).assessment, same(unsaved));
      await tester.tap(find.text('Save to session history'));
      await tester.pumpAndSettle();
      expect(find.byType(PatientProfileScreen), findsOneWidget);
      expect(provider.value.uri.path, '/patient-details');
      expect(repository.byId(id)!.assessments.length, 1);
      expect(identical(repository.byId(id)!.latest, unsaved), isTrue);
      await tester.scrollUntilVisible(find.text('Assessment history (1)'), 250,
          scrollable: find.descendant(of: find.byType(PatientProfileScreen), matching: find.byType(Scrollable)).first);
      final row = find.bySemanticsLabel(RegExp('Open result and explanation'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, '/result');
      expect(find.text('Saved result'), findsOneWidget);
      expect(find.text('Save to session history'), findsNothing);
      await tester.scrollUntilVisible(find.byType(ExplanationButton), 200,
          scrollable: find.descendant(of: find.byType(ResultScreen), matching: find.byType(Scrollable)).first);
      await Scrollable.ensureVisible(tester.element(find.byType(ExplanationButton)), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExplanationButton));
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, '/explanation');
      expect(tester.widget<ShapScreen>(find.byType(ShapScreen)).assessment, same(unsaved));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, '/result');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, '/patient-details');
      expect(find.byType(PatientProfileScreen), findsOneWidget);
      expect(requests.length, 1);
      expect(storage.entries, {DemoSession.key: DemoSession.marker});
      router.signOut();
      await tester.pumpAndSettle();
      expect(repository.byId(id), isNull);
      expect(storage.entries, isEmpty);
      provider.incoming('/assessment');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AssessmentInputScreen), findsNothing);
    });
  }

  testWidgets('missing patient record offers a safe return instead of a dead end', (tester) async {
    setScreen(tester, const Size(390, 844));
    final repository = PatientRepository()..saveAssessment(privateAssessment());
    final router = WebRouter(demoSession: DemoSession(TabStorage()));
    addTearDown(router.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, repository));
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!
        .push(AppNavigator.route(const PatientProfileScreen(patientId: 'private-patient')));
    await tester.pumpAndSettle();
    repository.clearSession();
    await tester.pumpAndSettle();
    expect(find.text('Record unavailable'), findsOneWidget);
    expect(find.text('Return to Patients').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Return to Patients'));
    await tester.pumpAndSettle();
    expect(router.currentConfiguration, '/patients');
    expect(find.byType(PatientsScreen), findsOneWidget);
    expect(repository.byId('private-patient'), isNull);
  });

  testWidgets('browser history clears a patient-associated draft without changing the patient list', (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final repository = PatientRepository();
    final router = WebRouter(demoSession: DemoSession(storage));
    final provider = HistoryRouteProvider()..incoming('/patients');
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, repository, provider: provider));
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!.push(AppNavigator.route(const PatientProfileScreen(patientId: 'P-0014')));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/patient-details');
    await tester.tap(find.text('New assessment'));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/assessment');
    expect(find.text('Copied from the last visit'), findsOneWidget);
    final count = repository.byId('P-0014')!.assessments.length;
    provider.incoming('/patients');
    await tester.pumpAndSettle();
    expect(find.byType(PatientsScreen), findsOneWidget);
    provider.incoming('/assessment');
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/assessment');
    expect(find.text(WebRouter.blankAssessmentNotice), findsOneWidget);
    expect(tester.widget<AssessmentInputScreen>(find.byType(AssessmentInputScreen)).patientId, isNull);
    expect(
        tester.widgetList<TextField>(find.byType(TextField)).every((field) => field.controller!.text.isEmpty), isTrue);
    expect(repository.byId('P-0014')!.assessments.length, count);
    expect(repository.sessionAssessmentCount, 0);
    expect(provider.reported.join(), isNot(contains('P-0014')));
    expect(storage.entries, {DemoSession.key: DemoSession.marker});
    provider.incoming('/patient-details');
    await tester.pumpAndSettle();
    expect(find.byType(PatientsScreen), findsOneWidget);
    expect(provider.value.uri.path, '/patients');
    expect(find.text(WebRouter.patientUnavailableNotice), findsOneWidget);
  });

  for (final editFirst in [false, true]) {
    testWidgets(
        'API failure ${editFirst ? 'Edit values' : 'Retry'} preserves inputs; discard starts blank without saving',
        (tester) async {
      setScreen(tester, const Size(390, 844));
      final item = cases().first;
      var calls = 0;
      final transport = MockClient((request) async {
        calls++;
        expect(jsonDecode(request.body), item['request']);
        return calls == 1 ? http.Response('Unavailable', 503) : http.Response(jsonEncode(item['response']), 200);
      });
      addTearDown(transport.close);
      final classifier =
          ApiRiskClassifier(baseUrl: Uri.parse('http://uci.test:8000'), client: transport, requireHttps: false);
      final repository = PatientRepository();
      final router = WebRouter(demoSession: DemoSession(TabStorage()));
      final provider = HistoryRouteProvider()..incoming('/assessment');
      addTearDown(router.dispose);
      addTearDown(provider.dispose);
      router.signIn();
      await tester.pumpWidget(routedApp(router, repository, provider: provider, classifier: classifier));
      await tester.pumpAndSettle();
      await enterValues(tester, item['request']);
      await finishClassification(tester);
      expect(find.textContaining("Couldn't get a risk result"), findsOneWidget);
      expect(provider.value.uri.path, '/processing');
      expect(find.byType(ResultScreen), findsNothing);
      expect(repository.sessionAssessmentCount, 0);
      if (editFirst) {
        await tester.tap(find.text('Edit values'));
        await tester.pumpAndSettle();
        expect(provider.value.uri.path, '/assessment');
        expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '25');
        await finishClassification(tester);
      } else {
        await tester.tap(find.text('Try again'));
        await tester.pump();
        await tester.pumpAndSettle();
      }
      expect(calls, 2);
      expect(find.byType(ResultScreen), findsOneWidget);
      final discard = find.text('Discard and assess another patient');
      await tester.scrollUntilVisible(discard, 250,
          scrollable: find.descendant(of: find.byType(ResultScreen), matching: find.byType(Scrollable)).first);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard & Start New'));
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentInputScreen), findsOneWidget);
      expect(provider.value.uri.path, '/assessment');
      expect(tester.widgetList<TextField>(find.byType(TextField)).every((field) => field.controller!.text.isEmpty),
          isTrue);
      expect(repository.sessionAssessmentCount, 0);
    });
  }
}
