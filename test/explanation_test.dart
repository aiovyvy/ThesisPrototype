import 'package:aiovy/data/repositories/app_settings.dart';
import 'package:aiovy/core/utils/formatters.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/models/maternal_indicators.dart';
import 'package:aiovy/models/risk_level.dart';
import 'package:aiovy/models/risk_result.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/screens/shap/shap_screen.dart';
import 'package:aiovy/widgets/explanation_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

RiskResult result(RiskLevel level, List<double> values) => RiskResult(
      riskLevel: level,
      probabilities: {for (final l in RiskLevel.values) l: l == level ? 0.7 : 0.15},
      modelName: 'Random Forest (UCI)',
      featureContributions: [
        for (var i = 0; i < 6; i++) FeatureContribution(indicator: Indicator.values[i], value: values[i])
      ],
      isDemo: false,
    );

Assessment assessment(RiskResult r) => Assessment(
      id: 'explanation-test',
      patientId: 'P-0099',
      timestamp: DateTime(2026, 10, 22),
      indicators: apiExampleIndicators,
      result: r,
      assessedBy: 'Test clinician',
    );

void main() {
  setUpAll(loadTestFonts);

  for (final level in RiskLevel.values) {
    test('${level.label}: signs are relative to the prediction at every magnitude', () {
      final r = result(level, [0.000001, -0.000001, 0, -0.4, 0.3, 0.2]);
      final f = ContributionFraming.of(r);
      expect(f.describe(0.000001), 'Supports ${level.label}');
      expect(f.describe(-0.000001), 'Opposes ${level.label}');
      expect(f.describe(0), 'No contribution');
      final copy = f.summary(r.featureContributions);
      expect(copy, contains('Body Temperature [+0.3000] provided the largest support for ${level.label}'));
      expect(
          copy, contains('Blood Glucose [\u22120.4000] provided the largest opposing contribution to ${level.label}'));
      expect(copy, isNot(contains('higher risk')));
      expect(r.featureContributions.first.indicator, Indicator.age); // no input mutation
    });
  }

  test('zero-only, one-direction, missing, and tied explanations are accurate', () {
    final r = result(RiskLevel.low, [0, 0, 0, 0, 0, 0]);
    final f = ContributionFraming.of(r);
    expect(f.summary(r.featureContributions), startsWith('All returned contributions are zero.'));
    expect(contributionScale(r.featureContributions), 0);
    expect(f.summary([]), 'No contributions were returned for this assessment.');
    expect(f.summary(result(RiskLevel.low, [-0.1, 0, 0, 0, 0, 0]).featureContributions),
        startsWith('No indicator had a positive contribution supporting Low Risk.'));
    expect(f.summary(result(RiskLevel.low, [0.1, 0.1, 0, 0, 0, 0]).featureContributions),
        contains('Low Risk (tied). No indicator had a negative contribution.'));
    final ranked = rankedContributions(result(RiskLevel.low, [0, -0.4, 0.4, 0.1, -0.2, 0.3]).featureContributions);
    expect(ranked.map((c) => c.indicator), [
      Indicator.systolic,
      Indicator.diastolic,
      Indicator.heartRate,
      Indicator.bodyTemperature,
      Indicator.bloodGlucose,
      Indicator.age
    ]);
  });

  test('formatting preserves sign and precision including tiny contributions', () {
    expect(Fmt.contribution(0), '0.0000');
    expect(Fmt.contribution(-0.0), '0.0000');
    expect(Fmt.contribution(0.4376), '+0.4376');
    expect(Fmt.contribution(-0.000001), '\u22120.000001');
    expect(Fmt.contribution(0.000001), '+0.000001');
  });

  testWidgets('prominent button is full width, accessible, and opens the existing route', (tester) async {
    setScreen(tester, const Size(360, 780));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(testApp(ResultScreen(assessment: assessment(apiExampleResult))));
    final button = find.byType(ExplanationButton);
    await tester.scrollUntilVisible(button, 250, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.getSize(button).width, greaterThan(250));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(72));
    expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    expect(
        tester.getSemantics(find.byType(FilledButton)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Why did AI predict this?\nSee how your six indicators shaped this result',
        ));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(ShapScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    semantics.dispose();
  });

  for (final level in RiskLevel.values) {
    for (final size in [const Size(320, 568), const Size(1280, 900)]) {
      testWidgets('${level.label} six ranked indicators at $size and large text', (tester) async {
        setScreen(tester, size, textScale: 2);
        final r = result(level, [0, -0.4, 0.000001, 0.3, -0.02, 0.1]);
        await tester.pumpWidget(testApp(ShapScreen(assessment: assessment(r))));
        await tester.scrollUntilVisible(find.text(level.label), 150,
            scrollable: find.byType(Scrollable).first);
        expect(find.text(level.label), findsOneWidget);
        expect(find.textContaining('70% probability'), findsOneWidget);
        await tester.scrollUntilVisible(find.textContaining('142 mmHg'), 150,
            scrollable: find.byType(Scrollable).first);
        expect(find.textContaining('142 mmHg'), findsWidgets); // personalized summary
        for (final c in rankedContributions(r.featureContributions)) {
          final row = find.byKey(ValueKey('explanation-${c.indicator.name}'));
          await tester.scrollUntilVisible(row, 150, scrollable: find.byType(Scrollable).first);
          final widget = tester.widget<ContributionBar>(row);
          expect(widget.contribution.value, c.value);
          expect(widget.valueText, isNotEmpty);
          expect(find.descendant(of: row, matching: find.text(ContributionFraming.of(r).describe(c.value))),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        final limits = find.textContaining('It does not explain what medically caused a condition.');
        await tester.scrollUntilVisible(limits, 150, scrollable: find.byType(Scrollable).first);
        expect(limits, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('display units change without changing SHAP values or source inputs', (tester) async {
    setScreen(tester, const Size(360, 780));
    final settings = AppSettings()
      ..glucoseUnit = GlucoseUnit.mgdL
      ..tempUnit = TempUnit.celsius;
    await tester.pumpWidget(testApp(ShapScreen(assessment: assessment(apiExampleResult)), settings: settings));
    for (final entry in {
      Indicator.age: '32 yrs',
      Indicator.systolic: '142 mmHg',
      Indicator.diastolic: '92 mmHg',
      Indicator.bloodGlucose: '101 mg/dL',
      Indicator.bodyTemperature: '36.9\u00b0C',
      Indicator.heartRate: '82 bpm'
    }.entries) {
      final row = find.byKey(ValueKey('explanation-${entry.key.name}'));
      await tester.scrollUntilVisible(row, 150, scrollable: find.byType(Scrollable).first);
      final bar = tester.widget<ContributionBar>(row);
      expect(bar.valueText, entry.value);
      expect(bar.contribution.value,
          apiExampleResult.featureContributions.firstWhere((c) => c.indicator == entry.key).value);
    }
    expect(apiExampleIndicators.bloodGlucose, 5.6);
    expect(apiExampleIndicators.bodyTempF, 98.4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-zero rows are neutral and draw no colored contribution width', (tester) async {
    setScreen(tester, const Size(320, 568), textScale: 2);
    final r = result(RiskLevel.moderate, [0, 0, 0, 0, 0, 0]);
    await tester.pumpWidget(testApp(ShapScreen(assessment: assessment(r))));
    final row = find.byKey(const ValueKey('explanation-age'));
    await tester.scrollUntilVisible(row, 150, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: row, matching: find.text('No contribution')), findsOneWidget);
    final positions = tester.widgetList<Positioned>(find.descendant(of: row, matching: find.byType(Positioned)));
    expect(positions.any((p) => p.width == 0), isTrue);
    expect(tester.takeException(), isNull);
  });
}
