import 'package:aiovy/core/theme/app_theme.dart';
import 'package:aiovy/data/mock/mock_clinician.dart';
import 'package:aiovy/data/repositories/app_settings.dart';
import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/navigation/main_shell.dart';
import 'package:aiovy/navigation/web_router.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/research/research_demo_screen.dart';
import 'package:aiovy/screens/settings/settings_screen.dart';
import 'package:aiovy/services/mock_risk_classifier.dart';
import 'package:aiovy/state/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/research_fixtures.dart';

class HistoryRouteProvider extends RouteInformationProvider with ChangeNotifier {
  RouteInformation _value = RouteInformation(uri: Uri(path: '/dashboard'));
  final reported = <String>[];
  @override
  RouteInformation get value => _value;
  void incoming(String path) {
    _value = RouteInformation(uri: Uri(path: path));
    notifyListeners();
  }

  @override
  void routerReportsNewRouteInformation(RouteInformation information,
      {RouteInformationReportingType type = RouteInformationReportingType.none}) {
    _value = information;
    reported.add(information.uri.path);
  }
}

Widget routedApp(WebRouter router, PatientRepository repository, {RouteInformationProvider? provider}) => AppScope(
      repository: repository,
      settings: AppSettings(),
      classifier: const MockRiskClassifier(),
      clinician: MockClinician.demo,
      child: MaterialApp.router(
          theme: AppTheme.light(),
          routerDelegate: router,
          routeInformationProvider: provider ??
              PlatformRouteInformationProvider(
                  initialRouteInformation: RouteInformation(uri: Uri(path: router.currentConfiguration))),
          routeInformationParser: WebRouteParser()),
    );

void main() {
  setUpAll(loadTestFonts);

  test('URL parser accepts only safe destination paths and removes query data', () async {
    final parser = WebRouteParser();
    expect(
        await parser.parseRouteInformation(RouteInformation(uri: Uri.parse('/settings?password=secret'))), '/settings');
    expect(await parser.parseRouteInformation(RouteInformation(uri: Uri.parse('/patient/123'))), '/');
    expect(parser.restoreRouteInformation('/research-demonstration').uri.toString(), '/research-demonstration/R1');
    expect(
        await parser
            .parseRouteInformation(RouteInformation(uri: Uri.parse('/research-demonstration/R4?token=discard'))),
        '/research-demonstration/R4');
    expect(await parser.parseRouteInformation(RouteInformation(uri: Uri.parse('/research-demonstration/patient-123'))),
        '/research-demonstration/R1');
  });

  testWidgets('public research restores every selected example without creating a session', (tester) async {
    setScreen(tester, const Size(390, 844));
    final repository = PatientRepository();
    final patientCount = repository.patients.length;
    for (final id in ['R1', 'R2', 'R3', 'R4', 'R5', 'R6']) {
      // A new router represents a refresh: no prior in-memory demo access.
      final client = fixedClient();
      final router = WebRouter(researchClient: client);
      await router.setNewRoutePath('/research-demonstration/$id');
      await tester.pumpWidget(routedApp(router, repository));
      await tester.pumpAndSettle();
      expect(router.signedIn, isFalse);
      expect(router.currentConfiguration, '/research-demonstration/$id');
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Example $id · Held-out set'), findsOneWidget);
      expect(find.text('Model prediction'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      client.close();
    }
    expect(repository.sessionAssessmentCount, 0);
    expect(repository.patients.length, patientCount);
  });

  testWidgets('public page builds with no patient repository or application scope', (tester) async {
    setScreen(tester, const Size(390, 844));
    final client = fixedClient();
    final router = WebRouter(researchClient: client);
    addTearDown(client.close);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
        theme: AppTheme.light(),
        routerDelegate: router,
        routeInformationParser: WebRouteParser(),
        routeInformationProvider: PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(uri: Uri(path: '/research-demonstration/R4')))));
    await tester.pumpAndSettle();
    expect(find.text('Example R4 · Held-out set'), findsOneWidget);
    expect(find.text('Model prediction'), findsOneWidget);
    expect(find.byType(AppScope), findsNothing);
    expect(router.signedIn, isFalse);
  });

  testWidgets('example selection updates URL; Back and Forward restore selection and result', (tester) async {
    setScreen(tester, const Size(390, 844));
    final client = fixedClient();
    final router = WebRouter(researchClient: client);
    final provider = HistoryRouteProvider()..incoming('/research-demonstration/R2');
    addTearDown(client.close);
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    await tester.pumpWidget(routedApp(router, PatientRepository(), provider: provider));
    await tester.pumpAndSettle();
    expect(find.text('Example R2 · Held-out set'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('select-R5')));
    await tester.pumpAndSettle();
    expect(provider.reported.last, '/research-demonstration/R5');
    expect(find.text('Example R5 · Held-out set'), findsOneWidget);
    provider.incoming('/research-demonstration/R2');
    await tester.pumpAndSettle();
    expect(find.text('Example R2 · Held-out set'), findsOneWidget);
    provider.incoming('/research-demonstration/R5');
    await tester.pumpAndSettle();
    expect(find.text('Example R5 · Held-out set'), findsOneWidget);
    expect(router.signedIn, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.currentConfiguration, '/');
    expect(find.byType(MainShell), findsNothing);
  });

  for (final location in ['/dashboard', '/settings', '/profile', '/patients']) {
    testWidgets('refresh $location requires sign-in and restores destination', (tester) async {
      setScreen(tester, const Size(390, 844));
      final router = WebRouter();
      addTearDown(router.dispose);
      await router.setNewRoutePath(location);
      await tester.pumpWidget(routedApp(router, PatientRepository()));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(router.currentConfiguration, location);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(router.signedIn, isTrue);
      expect(router.currentConfiguration, location);
      expect(find.byType(LoginScreen), findsNothing);
      if (location == '/settings') expect(find.byType(SettingsScreen), findsOneWidget);
      if (location == '/research-demonstration') expect(find.byType(ResearchDemoScreen), findsOneWidget);
    });
  }

  testWidgets('Back/Forward destinations stay guarded after logout and clear session records', (tester) async {
    setScreen(tester, const Size(390, 844));
    final router = WebRouter();
    addTearDown(router.dispose);
    final repository = PatientRepository();
    await router.setNewRoutePath('/dashboard');
    router.signIn();
    await tester.pumpWidget(routedApp(router, repository));
    await tester.pumpAndSettle();
    router.go('/settings');
    await tester.pumpAndSettle();
    router.go('/research-demonstration');
    await tester.pumpAndSettle();
    // Platform route delivery is how Router receives browser Back/Forward.
    await router.setNewRoutePath('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ResearchDemoScreen), findsNothing);
    await router.setNewRoutePath('/research-demonstration');
    await tester.pumpAndSettle();
    expect(find.byType(ResearchDemoScreen), findsOneWidget);
    router.go('/profile');
    await tester.pumpAndSettle();
    repository.saveAssessment(Assessment(
        id: 'test-session',
        patientId: 'session-only',
        timestamp: DateTime(2026, 10, 23),
        indicators: apiExampleIndicators,
        result: apiExampleResult,
        assessedBy: 'Synthetic tester'));
    await tester.scrollUntilVisible(find.text('Sign Out'), 250);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
    await tester.pumpAndSettle();
    expect(router.signedIn, isFalse);
    expect(router.currentConfiguration, '/login');
    expect(repository.sessionAssessmentCount, 0);
    expect(repository.byId('session-only'), isNull);
    for (final path in ['/dashboard', '/settings', '/profile', '/patients']) {
      await router.setNewRoutePath(path);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(ResearchDemoScreen), findsNothing);
    }
  });

  testWidgets('in-app back updates URL destination and tabs report their routes', (tester) async {
    setScreen(tester, const Size(390, 844));
    final router = WebRouter();
    addTearDown(router.dispose);
    await router.setNewRoutePath('/dashboard');
    router.signIn();
    router.go('/research-demonstration/R1');
    await tester.pumpWidget(routedApp(router, PatientRepository()));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.currentConfiguration, '/settings');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(router.currentConfiguration, '/dashboard');
    AppNavigator.currentTab.value = ShellTab.profile;
    await tester.pumpAndSettle();
    expect(router.currentConfiguration, '/profile');
  });

  testWidgets('Router reports URL changes and consumes Back/Forward route information', (tester) async {
    setScreen(tester, const Size(390, 844));
    final router = WebRouter();
    final provider = HistoryRouteProvider();
    addTearDown(router.dispose);
    addTearDown(provider.dispose);
    await router.setNewRoutePath('/dashboard');
    router.signIn();
    await tester.pumpWidget(routedApp(router, PatientRepository(), provider: provider));
    await tester.pumpAndSettle();
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(provider.reported.last, '/settings');
    router.go('/research-demonstration');
    await tester.pumpAndSettle();
    expect(provider.reported.last, '/research-demonstration/R1');
    provider.incoming('/settings'); // Browser Back event.
    await tester.pumpAndSettle();
    expect(router.currentConfiguration, '/settings');
    expect(find.byType(ResearchDemoScreen), findsNothing);
    provider.incoming('/research-demonstration'); // Browser Forward event.
    await tester.pumpAndSettle();
    expect(find.byType(ResearchDemoScreen), findsOneWidget);
    router.signOut();
    await tester.pumpAndSettle();
    provider.incoming('/research-demonstration');
    await tester.pumpAndSettle();
    expect(find.byType(ResearchDemoScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    provider.incoming('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ResearchDemoScreen), findsNothing);
  });
}
