import 'dart:async';
import 'dart:convert';

import 'package:aiovy/core/constants/app_strings.dart';
import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/models/maternal_indicators.dart';
import 'package:aiovy/models/risk_result.dart';
import 'package:aiovy/screens/assessment/assessment_input_screen.dart';
import 'package:aiovy/screens/home/home_screen.dart';
import 'package:aiovy/screens/patient_profile/patient_profile_screen.dart';
import 'package:aiovy/screens/patients/patients_screen.dart';
import 'package:aiovy/screens/processing/processing_screen.dart';
import 'package:aiovy/screens/research/research_demo_screen.dart';
import 'package:aiovy/screens/research/research_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/screens/shap/shap_screen.dart';
import 'package:aiovy/services/api_risk_classifier.dart';
import 'package:aiovy/services/mock_risk_classifier.dart';
import 'package:aiovy/services/research_demo_client.dart';
import 'package:aiovy/services/risk_classifier.dart';
import 'package:aiovy/widgets/research_disclaimer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/research_fixtures.dart';
import 'helpers/test_app.dart';

Assessment example(bool api) => Assessment(
      id: 'synthetic-disclaimer-example',
      patientId: 'synthetic-disclaimer-record',
      timestamp: DateTime(2026, 10, 27),
      indicators: apiExampleIndicators,
      assessedBy: 'Synthetic tester',
      result: api
          ? apiExampleResult
          : RiskResult(
              riskLevel: apiExampleResult.riskLevel,
              probabilities: apiExampleResult.probabilities,
              modelName: 'Simulated classifier',
              featureContributions: apiExampleResult.featureContributions,
              isDemo: true,
            ),
    );

void checkNotice(WidgetTester tester) {
  expect(find.byType(ResearchDisclaimer), findsOneWidget);
  final finder = find.text(AppStrings.researchDisclaimer);
  expect(finder, findsOneWidget);
  final text = tester.widget<Text>(finder);
  expect(text.style!.fontSize, 14);
  expect(text.maxLines, isNull);
  expect(text.overflow, isNot(TextOverflow.ellipsis));
  expect(tester.renderObject<RenderParagraph>(finder).didExceedMaxLines, isFalse);
  expect(find.bySemanticsLabel(AppStrings.researchDisclaimer), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> revealNotice(WidgetTester tester) async {
  final finder = find.byType(ResearchDisclaimer);
  final viewport = Scrollable.of(tester.element(finder));
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  expect(find.text(AppStrings.researchDisclaimer).hitTestable(), findsOneWidget);
  // A notice taller than a small viewport remains readable by scrolling.
  final rect = tester.getRect(finder);
  final scrollRect = tester.getRect(find.byWidget(viewport.widget));
  expect(rect.overlaps(scrollRect), isTrue);
}

void main() {
  setUpAll(loadTestFonts);

  test('shared wording is exact', () {
    expect(AppStrings.researchDisclaimer,
        'Research demonstration only. Not clinically validated. Does not replace professional clinical judgment. Do not use for clinical decisions.');
  });

  for (final width in [320.0, 390.0]) {
    for (final api in [false, true]) {
      final mode = api ? 'API-enabled' : 'simulated';

      testWidgets('one accessible disclaimer across screens in $mode mode at ${width}px and 200% text', (tester) async {
        setScreen(tester, Size(width, 844), textScale: 2);
        final semantics = tester.ensureSemantics();
        try {
          final classifier = api ? FakeApiClassifier() : const MockRiskClassifier(latency: Duration.zero);
          final assessment = example(api);
          final research = fixedClient();
          addTearDown(research.close);
          final screens = <(String, Widget, bool)>[
            ('Home', const HomeScreen(), false),
            ('Assessment', const AssessmentInputScreen(), false),
            ('Patients', const PatientsScreen(), false),
            ('Patient Details and History', const PatientProfileScreen(patientId: 'P-0014'), false),
            ('Missing record', const PatientProfileScreen(patientId: 'absent'), false),
            ('New result', ResultScreen(assessment: assessment), false),
            ('Saved result', ResultScreen(assessment: assessment), true),
            ('SHAP', ShapScreen(assessment: assessment), false),
            ('Model information', const ResearchScreen(), false),
            ('Research', ResearchDemoScreen(client: research), false),
          ];
          for (final (name, screen, saved) in screens) {
            await tester.pumpWidget(const SizedBox.shrink());
            // Scope list-screen geometry to the shared notice. Seeded patient
            // row layouts have separate coverage and are not changed by FR-08.
            final repository = (name == 'Home' || name == 'Patients')
                ? PatientRepository(seed: [])
                : PatientRepository();
            if (saved) repository.saveAssessment(assessment);
            await tester.pumpWidget(testApp(screen, repository: repository, classifier: classifier));
            await tester.pumpAndSettle();
            // Result lists build lazily; reach their final notice before checking.
            if (name.contains('result')) {
              final scroll =
                  find.descendant(of: find.byKey(const ValueKey('result-scroll')), matching: find.byType(Scrollable));
              final position = tester.state<ScrollableState>(scroll).position;
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
            }
            checkNotice(tester);
            await revealNotice(tester);
            if (name == 'New result') {
              expect(find.text('Save to patient record').hitTestable(), findsOneWidget);
              final notice = tester.getRect(find.byType(ResearchDisclaimer));
              final footer = tester.getRect(find.byKey(const ValueKey('result-actions')));
              expect(notice.bottom, lessThanOrEqualTo(footer.top));
            }
            if (name == 'Saved result') expect(find.text('Save to patient record'), findsNothing);
            if (name == 'Assessment') {
              await tester.scrollUntilVisible(find.text(AppStrings.syntheticDataOnly), 200,
                  scrollable: find.byType(Scrollable).first);
              expect(find.text(AppStrings.syntheticDataOnly), findsOneWidget);
            }
            if (name == 'Home' || name == 'Patients') {
              if (!api) {
                await tester.scrollUntilVisible(find.textContaining('Demo mode: every prediction is simulated'), 200,
                    scrollable: find.byType(Scrollable).first);
              }
              expect(
                  find.textContaining('Demo mode: every prediction is simulated'), api ? findsNothing : findsOneWidget);
            }
            if (name == 'Research') {
              expect(find.text('Experimental research model'), findsOneWidget);
              expect(find.textContaining('Source unit labels conflict'), findsOneWidget);
            }
            expect(repository.sessionAssessmentCount, saved ? 1 : 0);
            expect(tester.takeException(), isNull, reason: name);
          }
          if (classifier is FakeApiClassifier) expect(classifier.calls, 0);
        } finally {
          semantics.dispose();
        }
      });

      testWidgets('processing loading/error notice and Retry remain accessible in $mode at ${width}px', (tester) async {
        setScreen(tester, Size(width, 568), textScale: 2);
        final semantics = tester.ensureSemantics();
        try {
          var calls = 0;
          final transport = MockClient((_) async {
            calls++;
            return http.Response('Unavailable', 503);
          });
          addTearDown(transport.close);
          final RiskClassifier classifier = api
              ? ApiRiskClassifier(baseUrl: Uri.parse('http://uci.test'), client: transport, requireHttps: false)
              : _FailingDemo();
          await tester.pumpWidget(testApp(
              const ProcessingScreen(patientId: 'synthetic', indicators: apiExampleIndicators, isNewPatient: true),
              classifier: classifier));
          await tester.pump(const Duration(milliseconds: 100));
          checkNotice(tester);
          await revealNotice(tester);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          checkNotice(tester);
          await revealNotice(tester);
          expect(find.text('Try again').hitTestable(), findsOneWidget);
          expect(find.byType(ResultScreen), findsNothing);
          await tester.tap(find.text('Try again'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          checkNotice(tester);
          if (api) expect(calls, 2);
          expect(find.text('Try again').hitTestable(), findsOneWidget);
        } finally {
          semantics.dispose();
        }
      });

      testWidgets('research disclaimer survives loading, failure and Retry in $mode at ${width}px', (tester) async {
        setScreen(tester, Size(width, 568), textScale: 2);
        final semantics = tester.ensureSemantics();
        try {
          final first = Completer<http.Response>();
          var calls = 0;
          final client = ResearchDemoClient(
              baseUrl: Uri.parse('http://research.test'),
              client: MockClient((_) {
                calls++;
                return calls == 1 ? first.future : Future.value(http.Response(jsonEncode(fixtures().first), 200));
              }));
          addTearDown(client.close);
          await tester.pumpWidget(testApp(ResearchDemoScreen(client: client),
              classifier: api ? FakeApiClassifier() : const MockRiskClassifier(latency: Duration.zero)));
          await tester.pump(const Duration(milliseconds: 100));
          checkNotice(tester);
          first.complete(http.Response('Unavailable', 503));
          await tester.pumpAndSettle();
          checkNotice(tester);
          await tester.scrollUntilVisible(find.text('Retry'), 150, scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(calls, 2);
          expect(find.text('Model prediction'), findsOneWidget);
          await tester.scrollUntilVisible(find.byType(ResearchDisclaimer), -200,
              scrollable: find.byType(Scrollable).first);
          checkNotice(tester);
          await revealNotice(tester);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}

class _FailingDemo implements RiskClassifier {
  @override
  bool get isDemo => true;
  @override
  String get modelName => 'Simulated classifier';
  @override
  Future<RiskResult> classify(MaternalIndicators indicators) async =>
      throw const RiskClassifierException('Synthetic test failure');
}
