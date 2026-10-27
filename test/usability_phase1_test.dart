import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/screens/assessment/assessment_input_screen.dart';
import 'package:aiovy/screens/settings/settings_screen.dart';
import 'package:aiovy/screens/patient_profile/patient_profile_screen.dart';
import 'package:aiovy/screens/home/home_screen.dart';
import 'package:aiovy/screens/patients/patients_screen.dart';
import 'package:aiovy/services/mock_risk_classifier.dart';
import 'package:aiovy/screens/login/login_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/screens/welcome/welcome_screen.dart';
import 'package:aiovy/screens/welcome/onboarding_screen.dart';
import 'package:aiovy/navigation/app_navigator.dart';
import 'package:aiovy/models/risk_level.dart';
import 'package:aiovy/widgets/bottom_nav.dart';
import 'package:aiovy/widgets/app_header.dart';
import 'package:aiovy/widgets/settings_widgets.dart';
import 'package:aiovy/widgets/buttons.dart';
import 'package:aiovy/widgets/explanation_widgets.dart';
import 'package:aiovy/widgets/patient_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void activate(WidgetTester tester, Finder finder) {
  final node = tester.getSemantics(finder);
  expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  node.owner!.performAction(node.id, SemanticsAction.tap);
}

void main() {
  setUpAll(loadTestFonts);
  testWidgets('shared primary button semantic activation calls its action once', (tester) async {
    final semantics = tester.ensureSemantics();

    try {
      var calls = 0;
      await tester.pumpWidget(testApp(Scaffold(body: PrimaryButton(label: 'Action', onPressed: () => calls++))));
      activate(tester, find.bySemanticsLabel('Action'));
      await tester.pump();
      expect(calls, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('long shared action labels remain complete at 320px and 200%', (tester) async {
    setScreen(tester, const Size(320, 568), textScale: 2);
    await tester.pumpWidget(testApp(Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              PrimaryButton(label: 'New assessment', leadingIcon: Icons.add, onPressed: () {}),
              PrimaryButton(label: 'Continue to sign in', trailingIcon: Icons.arrow_forward, onPressed: () {}),
            ])))));
    for (final label in ['New assessment', 'Continue to sign in']) {
      expect(tester.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines, isFalse);
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final kind in ['secondary', 'icon']) {
    testWidgets('$kind button semantic activation calls its action once', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var calls = 0;
        final button = kind == 'secondary'
            ? SecondaryButton(label: 'Action', onPressed: () => calls++)
            : RoundIconButton(icon: Icons.add, tooltip: 'Action', onPressed: () => calls++);
        await tester.pumpWidget(testApp(Scaffold(body: button)));
        activate(tester, find.bySemanticsLabel('Action'));
        await tester.pump();
        expect(calls, 1);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final loading in [false, true]) {
    testWidgets('disabled/loading $loading primary exposes no activation', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var calls = 0;
        await tester.pumpWidget(testApp(Scaffold(
            body: PrimaryButton(label: 'Unavailable', loading: loading, onPressed: loading ? () => calls++ : null))));
        expect(
            tester.getSemantics(find.bySemanticsLabel('Unavailable')).getSemanticsData().hasAction(SemanticsAction.tap),
            isFalse);
        expect(calls, 0);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('bottom navigation semantic activation selects exactly once per action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final selections = <ShellTab>[];
      await tester.pumpWidget(
          testApp(Scaffold(bottomNavigationBar: AiovyBottomNav(current: ShellTab.home, onSelect: selections.add))));
      for (final (index, label) in ['Home tab', 'Patients tab', 'Profile tab'].indexed) {
        activate(tester, find.bySemanticsLabel(label));
        await tester.pump();
        expect(selections, ShellTab.values.take(index + 1).toList());
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('patient and assessment row semantics invoke their callback once', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var patients = 0, assessments = 0;
      final patient = PatientRepository().byId('P-0014')!;
      await tester.pumpWidget(testApp(Scaffold(
          body: ListView(children: [
        PatientListRow(patient: patient, onTap: () => patients++),
        AssessmentListRow(assessment: patient.latest!, onTap: () => assessments++),
      ]))));
      activate(tester, find.byType(PatientListRow));
      await tester.pump();
      expect(patients, 1);
      expect(assessments, 0);
      activate(tester, find.byType(AssessmentListRow));
      await tester.pump();
      expect(patients, 1);
      expect(assessments, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('history semantic activation opens one saved result and Back returns to the record', (tester) async {
    setScreen(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    try {
      final repo = PatientRepository();
      await tester.pumpWidget(testApp(const PatientProfileScreen(patientId: 'P-0014'), repository: repo));
      expect(find.byTooltip('Export or print record'), findsNothing);
      final history = find
          .byWidgetPredicate(
              (w) => w is Semantics && (w.properties.label?.endsWith('Open result and explanation.') ?? false))
          .first;
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      activate(tester, history);
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(repo.isSaved(tester.widget<ResultScreen>(find.byType(ResultScreen)).assessment), isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PatientProfileScreen), findsOneWidget);
      expect(find.byType(ResultScreen), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Home instruction and semantic start open one assessment without an API call', (tester) async {
    setScreen(tester, const Size(390, 844));
    final semantics = tester.ensureSemantics();
    try {
      final classifier = FakeApiClassifier();
      await tester
          .pumpWidget(testApp(const HomeScreen(), repository: PatientRepository(seed: []), classifier: classifier));
      expect(find.textContaining('Find saved session assessments under Patients'), findsOneWidget);
      final start =
          find.bySemanticsLabel('New assessment. Enter six maternal indicators to get a risk classification.');
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      activate(tester, start);
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentInputScreen), findsOneWidget);
      expect(classifier.calls, 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile avatar semantic action and unit selector activate once', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      AppNavigator.currentTab.value = ShellTab.home;
      var tabs = 0;
      void changed() {
        tabs++;
      }

      AppNavigator.currentTab.addListener(changed);
      try {
        await tester.pumpWidget(testApp(const Scaffold(body: HeaderAvatar())));
        activate(tester, find.bySemanticsLabel('Clinician profile'));
        await tester.pump();
        expect(AppNavigator.currentTab.value, ShellTab.profile);
        expect(tabs, 1);
      } finally {
        AppNavigator.currentTab.removeListener(changed);
        AppNavigator.currentTab.value = ShellTab.home;
      }
      final choices = <String>[];
      await tester.pumpWidget(testApp(Scaffold(
          body: SegmentedToggle<String>(
              options: const ['First', 'Second'], selected: 'First', labelOf: (v) => v, onChanged: choices.add))));
      activate(tester, find.bySemanticsLabel('Second'));
      await tester.pump();
      expect(choices, ['Second']);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Welcome and onboarding communicate research-only and simulated explanations', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(testApp(const WelcomeScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('synthetic examples'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('heuristic demo scores, not real SHAP'), findsOneWidget);
    expect(find.textContaining('Neither explains medical causes'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    for (final api in [false, true]) {
      testWidgets('populated Home and Patients at $width and 200% in API mode $api', (tester) async {
        setScreen(tester, Size(width, 568), textScale: 2);
        for (final screen in [const HomeScreen(), const PatientsScreen()]) {
          await tester.pumpWidget(const SizedBox.shrink());
          final repo = PatientRepository();
          await tester.pumpWidget(testApp(screen,
              repository: repo,
              classifier: api ? FakeApiClassifier() : const MockRiskClassifier(latency: Duration.zero)));
          await tester.pumpAndSettle();
          final id = screen is HomeScreen
              ? repo.patients.firstWhere((p) => p.currentRisk == RiskLevel.high).id
              : repo.patients.first.id;
          final row = find.byWidgetPredicate((w) => w is PatientListRow && w.patient.id == id);
          await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          expect(find.byType(PatientListRow), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('demo login at $width and 200% discourages real credentials', (tester) async {
      setScreen(tester, Size(width, 568), textScale: 2);
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Do not enter real credentials'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.text('Remember this workstation'), findsNothing);
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
      expect(fields.every((f) => f.controller!.text.isNotEmpty), isTrue);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('populated patient and assessment rows at $width and 200% preserve full text', (tester) async {
      setScreen(tester, Size(width, 844), textScale: 2);
      final patient = PatientRepository().byId('P-0014')!;
      await tester.pumpWidget(testApp(
          Scaffold(
              body: ListView(padding: const EdgeInsets.all(16), children: [
            PatientListRow(patient: patient, onTap: () {}),
            AssessmentListRow(assessment: patient.latest!, onTap: () {}),
          ])),
          classifier: FakeApiClassifier()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(patient.id), findsOneWidget);
      expect(find.text('Simulated'), findsNWidgets(2));
      for (final element in find.byType(Text).evaluate()) {
        expect(tester.renderObject<RenderParagraph>(find.byWidget(element.widget)).didExceedMaxLines, isFalse);
      }
    });

    testWidgets('assessment error footer and keyboard at $width and 200% remain usable', (tester) async {
      setScreen(tester, Size(width, 568), textScale: 2);
      await tester.pumpWidget(testApp(const AssessmentInputScreen()));
      await tester.tap(find.text('Assess risk'));
      await tester.pumpAndSettle();
      expect(find.text('Check the highlighted values'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('Assess risk').hitTestable(), findsOneWidget);
      expect(find.text('Check the highlighted values'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filled measurement inputs at $width and 200% keep a full line above the keyboard', (tester) async {
      setScreen(tester, Size(width, 568), textScale: 2);
      await tester.pumpWidget(testApp(const AssessmentInputScreen()));
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      for (final (range, value) in [
        ('12\u201365', '32'),
        ('60\u2013240', '142'),
        ('40\u2013160', '92'),
        ('2\u201325', '5.6'),
        ('90\u2013110', '98.4'),
        ('40\u2013200', '75')
      ]) {
        final input = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == range);
        await tester.scrollUntilVisible(input, 100, scrollable: find.byType(Scrollable).first);
        await tester.enterText(input, value);
        await tester.pumpAndSettle();
        await tester.ensureVisible(input);
        await tester.pumpAndSettle();
        final editable = tester
            .state<EditableTextState>(find.descendant(of: input, matching: find.byType(EditableText)))
            .renderEditable;
        expect(editable.size.height, greaterThanOrEqualTo(editable.preferredLineHeight), reason: range);
        expect(editable.maxScrollExtent, 0, reason: range);
        expect(find.text('Assess risk').hitTestable(), findsOneWidget);
        expect(tester.getRect(input).bottom, lessThanOrEqualTo(tester.getRect(find.byType(PrimaryButton)).top));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('probability labels at $width and 200% are complete', (tester) async {
      setScreen(tester, Size(width, 568), textScale: 2);
      await tester.pumpWidget(testApp(Scaffold(
          body: Padding(padding: const EdgeInsets.all(32), child: ProbabilityBars(result: apiExampleResult)))));
      await tester.pumpAndSettle();
      for (final label in ['Low', 'Moderate', 'High']) {
        expect(tester.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings advisory at $width and 200% can be read and dismissed', (tester) async {
      setScreen(tester, Size(width, 568), textScale: 2);
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.scrollUntilVisible(find.text('Clinical Disclaimer'), 300);
      await tester.ensureVisible(find.text('Clinical Disclaimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clinical Disclaimer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final close = find.text('Acknowledge & Close');
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
