import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/navigation/demo_mode_storage.dart';
import 'package:aiovy/navigation/main_shell.dart';
import 'package:aiovy/navigation/web_router.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/screens/research/research_screen.dart';
import 'package:aiovy/screens/profile/doctor_profile_screen.dart';
import 'package:aiovy/screens/patients/patients_screen.dart';
import 'package:aiovy/screens/home/home_screen.dart';
import 'package:aiovy/screens/welcome/onboarding_screen.dart';
import 'package:aiovy/screens/welcome/welcome_screen.dart';
import 'package:aiovy/widgets/bottom_nav.dart';
import 'package:aiovy/screens/settings/settings_screen.dart';
import 'package:aiovy/screens/shap/shap_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'web_router_test.dart' show HistoryRouteProvider, routedApp;

class TabStorage implements DemoModeStorage, DemoModeEvents {
  final listeners = <void Function()>[];
  @override
  void Function() watch(void Function() validate) {
    listeners.add(validate);
    return () => listeners.remove(validate);
  }

  void resume() {
    for (final listener in List.of(listeners)) {
      listener();
    }
  }

  final entries = <String, String>{};
  bool blocked = false;
  final writes = <String>[];
  void check() {
    if (blocked) throw StateError('Storage blocked');
  }

  @override
  String? read() {
    check();
    return entries[DemoSession.key];
  }

  @override
  void write(String value) {
    check();
    entries[DemoSession.key] = value;
    writes.add(value);
  }

  @override
  void remove() {
    check();
    entries.remove(DemoSession.key);
  }
}

Assessment privateAssessment() => Assessment(
    id: 'private-assessment',
    patientId: 'private-patient',
    timestamp: DateTime(2026, 10, 23),
    indicators: apiExampleIndicators,
    result: apiExampleResult,
    assessedBy: 'private-clinician');

void main() {
  setUpAll(loadTestFonts);

  test('only a fixed non-secret mode marker is written; blocked or unknown values do not restore', () {
    final storage = TabStorage();
    final session = DemoSession(storage);
    expect(session.canRestore, isFalse);
    expect(session.enable(), isTrue);
    expect(storage.entries, {DemoSession.key: DemoSession.marker});
    expect(DemoSession(storage).canRestore, isTrue);
    expect(session.clear(), isTrue);
    expect(storage.entries, isEmpty);
    storage.entries[DemoSession.key] = 'unrecognized';
    expect(session.canRestore, isFalse);
    storage.blocked = true;
    expect(session.canRestore, isFalse);
    expect(session.enable(), isFalse);
    expect(session.clear(), isFalse);
  });

  for (final path in ['/dashboard', '/settings', '/patients', '/profile', '/how-aiovy-works']) {
    testWidgets('DEMO-ONLY marker restores $path on refresh without restoring records', (tester) async {
      setScreen(tester, const Size(390, 844));
      final storage = TabStorage();
      final old = WebRouter(demoSession: DemoSession(storage));
      old.signIn();
      old.go(path);
      final oldRepository = PatientRepository()..saveAssessment(privateAssessment());
      await tester.pumpWidget(routedApp(old, oldRepository));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      old.dispose();
      final freshRepository = PatientRepository();
      final refreshed = WebRouter(demoSession: DemoSession(storage));
      addTearDown(refreshed.dispose);
      await refreshed.setNewRoutePath(path);
      await tester.pumpWidget(routedApp(refreshed, freshRepository));
      await tester.pumpAndSettle();
      expect(refreshed.signedIn, isTrue);
      expect(refreshed.currentConfiguration, path);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell, skipOffstage: false), findsOneWidget);
      if (path == '/settings') expect(find.byType(SettingsScreen), findsOneWidget);
      if (path == '/how-aiovy-works') {
        expect(find.byType(ResearchScreen), findsOneWidget);
        expect(find.text(WebRouter.lostStateNotice), findsNothing);
      }
      expect(find.text(WebRouter.restoredNotice), findsOneWidget);
      expect(freshRepository.byId('private-patient'), isNull);
      expect(freshRepository.sessionAssessmentCount, 0);
      expect(storage.entries, {DemoSession.key: DemoSession.marker});
    });
  }

  for (final path in WebRouteParser.temporaryPaths.where((path) => path != '/patient-details')) {
    testWidgets('refresh/history of $path explains lost state and never recreates an assessment', (tester) async {
      setScreen(tester, const Size(390, 844));
      final storage = TabStorage();
      DemoSession(storage).enable();
      final router = WebRouter(demoSession: DemoSession(storage));
      addTearDown(router.dispose);
      await router.setNewRoutePath(path);
      final repository = PatientRepository();
      await tester.pumpWidget(routedApp(router, repository));
      await tester.pumpAndSettle();
      expect(router.currentConfiguration, '/dashboard');
      expect(find.text(WebRouter.lostStateNotice), findsOneWidget);
      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(ShapScreen), findsNothing);
      expect(repository.sessionAssessmentCount, 0);
      expect(storage.entries, {DemoSession.key: DemoSession.marker});
    });
  }

  testWidgets('real in-memory result/explanation report generic URLs, and logout removes the stack and marker',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final repository = PatientRepository();
    final router = WebRouter(demoSession: DemoSession(storage), onClearSession: repository.clearSession);
    final provider = HistoryRouteProvider();
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, repository, provider: provider));
    await tester.pumpAndSettle();
    final assessment = privateAssessment();
    repository.saveAssessment(assessment);
    router.navigatorKey.currentState!.push(AppNavigator.route(ResultScreen(assessment: assessment)));
    await tester.pumpAndSettle();
    expect(provider.reported.last, '/result');
    router.navigatorKey.currentState!.push(AppNavigator.route(ShapScreen(assessment: assessment)));
    await tester.pumpAndSettle();
    expect(provider.reported.last, '/explanation');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(provider.reported.last, '/result');
    expect(storage.entries, {DemoSession.key: DemoSession.marker});
    expect(provider.reported.join(), isNot(contains('private-')));
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(storage.entries, isEmpty);
    expect(repository.sessionAssessmentCount, 0);
    expect(repository.byId('private-patient'), isNull);
    expect(find.byType(ResultScreen), findsNothing);
    expect(find.byType(ShapScreen), findsNothing);
    for (final path in ['/result', '/explanation', '/dashboard', '/settings', '/patient-details']) {
      provider.incoming(path);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(ResultScreen), findsNothing);
      expect(find.byType(ShapScreen), findsNothing);
    }
    final refreshed = WebRouter(demoSession: DemoSession(storage));
    expect(refreshed.signedIn, isFalse);
    refreshed.dispose();
    expect(storage.writes.where((value) => value != DemoSession.marker && value != 'disabled'), isEmpty);
  });

  testWidgets('blocked browser storage keeps the memory-only gate and reports refresh limitation', (tester) async {
    final storage = TabStorage()..blocked = true;
    final router = WebRouter(demoSession: DemoSession(storage));
    addTearDown(router.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, PatientRepository()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Browser session storage is unavailable'), findsOneWidget);
    final fresh = WebRouter(demoSession: DemoSession(storage));
    expect(fresh.signedIn, isFalse);
    fresh.dispose();
  });

  testWidgets('cached-page resume revokes removed demo mode and blocks late result navigation', (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final repository = PatientRepository()..saveAssessment(privateAssessment());
    final router = WebRouter(demoSession: DemoSession(storage), onClearSession: repository.clearSession);
    addTearDown(router.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, repository));
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!.push(AppNavigator.route(ResultScreen(assessment: privateAssessment())));
    await tester.pumpAndSettle();
    final oldContext = tester.element(find.byType(ResultScreen));
    // Simulates an older document's Dart heap resuming after another document
    // in this tab has removed the marker during logout.
    storage.remove();
    storage.resume();
    expect(router.signedIn, isFalse);
    await AppNavigator.replace(oldContext, ResultScreen(assessment: privateAssessment()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ResultScreen), findsNothing);
    expect(repository.sessionAssessmentCount, 0);
    expect(storage.entries, isEmpty);
  });

  testWidgets('lost-state notice remains readable without overflowing a narrow enlarged-text page', (tester) async {
    setScreen(tester, const Size(320, 568), textScale: 2);
    final storage = TabStorage();
    DemoSession(storage).enable();
    final router = WebRouter(demoSession: DemoSession(storage));
    addTearDown(router.dispose);
    await router.setNewRoutePath('/result');
    await tester.pumpWidget(routedApp(router, PatientRepository()));
    await tester.pumpAndSettle();
    expect(find.text(WebRouter.lostStateNotice), findsOneWidget);
    expect(router.currentConfiguration, '/dashboard');
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible tabs, Settings and informational screen publish matching URLs and consume history',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final router = WebRouter(demoSession: DemoSession(storage));
    final provider = HistoryRouteProvider();
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, PatientRepository(), provider: provider));
    await tester.pumpAndSettle();
    for (final (label, path, type) in [
      ('Patients', '/patients', PatientsScreen),
      ('Profile', '/profile', DoctorProfileScreen),
      ('Home', '/dashboard', HomeScreen),
      ('Profile', '/profile', DoctorProfileScreen),
    ]) {
      await tester.tap(find.descendant(of: find.byType(AiovyBottomNav), matching: find.text(label)));
      await tester.pumpAndSettle();
      expect(provider.value.uri.path, path);
      expect(find.byType(type), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('How AIOVY Works'), 200,
        scrollable: find.descendant(of: find.byType(DoctorProfileScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('How AIOVY Works'));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/how-aiovy-works');
    expect(find.byType(ResearchScreen), findsOneWidget);
    provider.incoming('/profile');
    await tester.pumpAndSettle();
    expect(find.byType(DoctorProfileScreen), findsOneWidget);
    provider.incoming('/how-aiovy-works');
    await tester.pumpAndSettle();
    expect(find.byType(ResearchScreen), findsOneWidget);
    expect(provider.value.uri.path, '/how-aiovy-works');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/profile');
    await tester.scrollUntilVisible(find.text('Settings'), 200,
        scrollable: find.descendant(of: find.byType(DoctorProfileScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    router.signOut();
    provider.incoming('/how-aiovy-works');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ResearchScreen), findsNothing);
    expect(storage.entries, isEmpty);
  });

  testWidgets('information opened from SHAP gets its own URL and in-app Back keeps the live explanation',
      (tester) async {
    setScreen(tester, const Size(390, 844));
    final router = WebRouter(demoSession: DemoSession(TabStorage()));
    final provider = HistoryRouteProvider();
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    router.signIn();
    await tester.pumpWidget(routedApp(router, PatientRepository(), provider: provider));
    await tester.pumpAndSettle();
    router.navigatorKey.currentState!.push(AppNavigator.route(ShapScreen(assessment: privateAssessment())));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/explanation');
    final explanationContext = tester.element(find.byType(ShapScreen));
    AppNavigator.push(explanationContext, const ResearchScreen());
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/how-aiovy-works');
    expect(find.byType(ResearchScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/explanation');
    expect(find.byType(ShapScreen), findsOneWidget);
    provider.incoming('/how-aiovy-works');
    await tester.pumpAndSettle();
    expect(find.byType(ResearchScreen), findsOneWidget);
    expect(find.text(WebRouter.lostStateNotice), findsNothing);
  });

  testWidgets('public onboarding and login publish safe URLs without a session', (tester) async {
    final router = WebRouter(demoSession: DemoSession(TabStorage()));
    final provider = HistoryRouteProvider()..incoming('/');
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    await tester.pumpWidget(routedApp(router, PatientRepository(), provider: provider));
    await tester.pumpAndSettle();
    final welcomeContext = tester.element(find.byType(WelcomeScreen));
    AppNavigator.push(welcomeContext, const OnboardingScreen());
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/onboarding');
    provider.incoming('/onboarding');
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(provider.value.uri.path, '/login');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(router.signedIn, isFalse);
  });

  testWidgets('entering demo credentials persists only the fixed mode marker', (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = TabStorage();
    final router = WebRouter(demoSession: DemoSession(storage));
    addTearDown(router.dispose);
    await router.setNewRoutePath('/login');
    await tester.pumpWidget(routedApp(router, PatientRepository()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'private-email@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'private-password');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(router.signedIn, isTrue);
    expect(storage.entries, {DemoSession.key: DemoSession.marker});
    expect(storage.writes, [DemoSession.marker]);
    expect(router.currentConfiguration, '/dashboard');
  });

  for (final size in [const Size(320, 568), const Size(390, 844), const Size(1440, 900)]) {
    for (final textScale in [1.0, 2.0]) {
      for (final web in [false, true]) {
        testWidgets('result disclaimer clears sticky action at $size text $textScale web $web', (tester) async {
          setScreen(tester, size, textScale: textScale);
          final screen = ResultScreen(assessment: privateAssessment());
          if (web) {
            final router = WebRouter(demoSession: DemoSession(TabStorage()));
            addTearDown(router.dispose);
            router.signIn();
            await tester.pumpWidget(routedApp(router, PatientRepository()));
            await tester.pumpAndSettle();
            router.navigatorKey.currentState!.push(AppNavigator.route(screen));
          } else {
            await tester.pumpWidget(testApp(screen));
          }
          await tester.pumpAndSettle();
          final scroll =
              find.descendant(of: find.byKey(const ValueKey('result-scroll')), matching: find.byType(Scrollable));
          final position = tester.state<ScrollableState>(scroll).position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          final notice = tester.getRect(find.byKey(const ValueKey('result-disclaimer')));
          final footer = tester.getRect(find.byKey(const ValueKey('result-actions')));
          final viewport = tester.getRect(scroll);
          if (notice.height <= viewport.height - 16) {
            expect(notice.top, greaterThanOrEqualTo(viewport.top));
          } else {
            // The longer 14px FR-08 notice can exceed a short web viewport
            // with the demo banner at 200%. Its start and end must both be
            // reachable by scrolling, without moving the sticky Save footer.
            await Scrollable.ensureVisible(tester.element(find.byKey(const ValueKey('result-disclaimer'))),
                alignment: 0);
            await tester.pumpAndSettle();
            expect(tester.getRect(find.byKey(const ValueKey('result-disclaimer'))).top,
                greaterThanOrEqualTo(viewport.top - 1));
            expect(find.text('Save to session history').hitTestable(), findsOneWidget);
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
          }
          expect(notice.bottom, lessThanOrEqualTo(footer.top));
          expect(notice.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(find.text('Save to session history').hitTestable(), findsOneWidget);
          expect(tester.renderObject<RenderParagraph>(find.text('Save to session history')).didExceedMaxLines, isFalse);
          await tester.scrollUntilVisible(find.text('Discard and assess another patient'), -150, scrollable: scroll);
          expect(
              tester.renderObject<RenderParagraph>(find.text('Discard and assess another patient')).didExceedMaxLines,
              isFalse);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
