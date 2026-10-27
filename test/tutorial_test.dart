import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/navigation/demo_mode_storage.dart';
import 'package:aiovy/navigation/web_router.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/settings/settings_screen.dart';
import 'package:aiovy/screens/welcome/onboarding_screen.dart';
import 'package:aiovy/screens/welcome/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_session_test.dart' show TabStorage;
import 'helpers/test_app.dart';
import 'web_router_test.dart' show HistoryRouteProvider, routedApp;

Assessment syntheticAssessment() => Assessment(
    id: 'tutorial-synthetic',
    patientId: 'tutorial-demo',
    timestamp: DateTime(2026, 10, 27),
    indicators: apiExampleIndicators,
    result: apiExampleResult,
    assessedBy: 'Synthetic tester');

Future<void> openReplay(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Replay Tutorial'), 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.text('Replay Tutorial'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Replay Tutorial'));
  await tester.pumpAndSettle();
  expect(tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).replay, isTrue);
  expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
}

void semanticTap(WidgetTester tester, String label) {
  final node = tester.getSemantics(find.bySemanticsLabel(label));
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  node.owner!.performAction(node.id, SemanticsAction.tap);
}

Future<void> finishReplay(WidgetTester tester, String exit) async {
  if (exit == 'Done') {
    for (var step = 0; step < 2; step++) {
      semanticTap(tester, 'Next');
      await tester.pumpAndSettle();
    }
    semanticTap(tester, 'Done');
  } else if (exit == 'Back') {
    await tester.pageBack();
  } else {
    semanticTap(tester, 'Skip');
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  for (var skipAt = 0; skipAt < 3; skipAt++) {
    testWidgets('Welcome tutorial Skip on page ${skipAt + 1} still opens login', (tester) async {
      setScreen(tester, const Size(390, 844));
      final semantics = tester.ensureSemantics();
      try {
        final classifier = FakeApiClassifier();
        await tester.pumpWidget(testApp(const WelcomeScreen(), classifier: classifier));
        await tester.pumpAndSettle();
        semanticTap(tester, 'Get started');
        await tester.pumpAndSettle();
        for (var step = 0; step < skipAt; step++) {
          semanticTap(tester, 'Next');
          await tester.pumpAndSettle();
        }
        expect(find.bySemanticsLabel('Page ${skipAt + 1} of 3'), findsOneWidget);
        semanticTap(tester, 'Skip');
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(classifier.calls, 0);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final exit in ['Skip', 'Done', 'Back']) {
    testWidgets('mobile Settings replay $exit returns to the same Settings and preserves history', (tester) async {
      setScreen(tester, const Size(390, 844));
      final semantics = tester.ensureSemantics();
      try {
        final repo = PatientRepository();
        final assessment = syntheticAssessment();
        repo.saveAssessment(assessment);
        final classifier = FakeApiClassifier();
        await tester.pumpWidget(testApp(const SettingsScreen(), repository: repo, classifier: classifier));
        final settingsState = tester.element(find.byType(SettingsScreen));
        await openReplay(tester);
        await finishReplay(tester, exit);
        expect(tester.element(find.byType(SettingsScreen)), same(settingsState));
        expect(find.byType(LoginScreen), findsNothing);
        expect(repo.byId(assessment.patientId)!.latest, same(assessment));
        expect(repo.sessionAssessmentCount, 1);
        expect(classifier.calls, 0);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('web Settings replay $exit preserves access, URL and existing records', (tester) async {
      setScreen(tester, const Size(390, 844));
      final semantics = tester.ensureSemantics();
      final storage = TabStorage();
      final repo = PatientRepository()..saveAssessment(syntheticAssessment());
      final assessment = repo.byId('tutorial-demo')!.latest!;
      final classifier = FakeApiClassifier();
      final router = WebRouter(demoSession: DemoSession(storage), onClearSession: repo.clearSession);
      final provider = HistoryRouteProvider()..incoming('/settings');
      addTearDown(router.dispose);
      addTearDown(provider.dispose);
      try {
        router.signIn();
        final writes = List.of(storage.writes);
        await tester.pumpWidget(routedApp(router, repo, provider: provider, classifier: classifier));
        await tester.pumpAndSettle();
        await openReplay(tester);
        expect(provider.value.uri.path, '/onboarding');
        await finishReplay(tester, exit);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(provider.value.uri.path, '/settings');
        expect(router.signedIn, isTrue);
        expect(repo.byId(assessment.patientId)!.latest, same(assessment));
        expect(repo.sessionAssessmentCount, 1);
        expect(storage.entries, {DemoSession.key: DemoSession.marker});
        expect(storage.writes, writes);
        expect(classifier.calls, 0);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('unsigned web tutorial completion preserves welcome-to-login behavior', (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final router = WebRouter(demoSession: DemoSession(storage));
    final provider = HistoryRouteProvider()..incoming('/');
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    await tester.pumpWidget(routedApp(router, PatientRepository(), provider: provider));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/onboarding');
    expect(tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).replay, isFalse);
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Continue to sign in'));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/login');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(router.signedIn, isFalse);
    expect(storage.entries, isEmpty);
    expect(storage.writes, isEmpty);
  });

  testWidgets('Android-style system Back exits replay without clearing session history', (tester) async {
    setScreen(tester, const Size(390, 844));
    final repo = PatientRepository()..saveAssessment(syntheticAssessment());
    await tester.pumpWidget(testApp(const SettingsScreen(), repository: repo));
    await openReplay(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(repo.sessionAssessmentCount, 1);
  });

  testWidgets('restored tutorial and browser history return to Settings without another login or storage writes',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    final storage = TabStorage();
    DemoSession(storage).enable();
    final writes = List.of(storage.writes);
    final repo = PatientRepository(); // Refresh restores no entered records.
    final router = WebRouter(demoSession: DemoSession(storage));
    final provider = HistoryRouteProvider()..incoming('/onboarding');
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    try {
      await tester.pumpWidget(routedApp(router, repo, provider: provider));
      await tester.pumpAndSettle();
      expect(tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).replay, isTrue);
      await finishReplay(tester, 'Done');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(provider.value.uri.path, '/settings');
      provider.incoming('/onboarding');
      await tester.pumpAndSettle();
      await finishReplay(tester, 'Skip');
      expect(provider.value.uri.path, '/settings');
      expect(router.signedIn, isTrue);
      expect(repo.sessionAssessmentCount, 0);
      expect(storage.writes, writes);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('logout during replay clears records and cannot reopen protected Settings through history',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final repo = PatientRepository()..saveAssessment(syntheticAssessment());
    final router = WebRouter(demoSession: DemoSession(storage), onClearSession: repo.clearSession);
    final provider = HistoryRouteProvider()..incoming('/settings');
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, repo, provider: provider));
    await tester.pumpAndSettle();
    await openReplay(tester);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(router.signedIn, isFalse);
    expect(repo.sessionAssessmentCount, 0);
    expect(storage.entries, isEmpty);
    provider.incoming('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    provider.incoming('/onboarding');
    await tester.pumpAndSettle();
    expect(tester.widget<OnboardingScreen>(find.byType(OnboardingScreen)).replay, isFalse);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(router.signedIn, isFalse);
    expect(storage.entries, isEmpty);
  });

  for (final replay in [false, true]) {
    testWidgets('all tutorial instructions and controls at 320px/200%, replay $replay', (tester) async {
      setScreen(tester, const Size(320, 568), textScale: 2);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(testApp(replay ? const SettingsScreen() : const WelcomeScreen()));
        await tester.pumpAndSettle();
        if (replay) {
          await openReplay(tester);
        } else {
          await tester.ensureVisible(find.text('Get started'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Get started'));
          await tester.pumpAndSettle();
        }
        for (final (index, title)
            in ['Start a synthetic assessment', 'Understand the output', 'Save and revisit'].indexed) {
          expect(find.text(title), findsOneWidget);
          expect(find.bySemanticsLabel('Page ${index + 1} of 3'), findsOneWidget);
          final instruction = find.byWidgetPredicate((w) =>
              w is Text && (w.data?.startsWith(['From Home,', 'Review the Low,', 'Choose Save to'][index]) ?? false));
          final position = Scrollable.of(tester.element(instruction)).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.renderObject<RenderParagraph>(instruction).didExceedMaxLines, isFalse);
          final bottom = tester.getRect(instruction).bottom;
          expect(bottom, lessThanOrEqualTo(tester.getRect(find.byType(PageView)).bottom + 1));
          final next = index < 2
              ? 'Next'
              : replay
                  ? 'Done'
                  : 'Continue to sign in';
          expect(find.text(next).hitTestable(), findsOneWidget);
          expect(find.text('Skip').hitTestable(), findsOneWidget);
          expect(tester.renderObject<RenderParagraph>(find.text(next)).didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
          semanticTap(tester, next);
          await tester.pumpAndSettle();
        }
        expect(find.byType(replay ? SettingsScreen : LoginScreen), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  }
}
