import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/models/assessment.dart';
import 'package:aiovy/screens/assessment/assessment_input_screen.dart';
import 'package:aiovy/screens/patient_profile/patient_profile_screen.dart';
import 'package:aiovy/screens/result/result_screen.dart';
import 'package:aiovy/widgets/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

// Assert usable text geometry, not merely the absence of RenderFlex errors.
void expectUnbrokenWord(WidgetTester tester, Finder finder, int start, int end) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end)), hasLength(1));
}

void main() {
  setUpAll(loadTestFonts);
  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (390.0, 1.0)]) {
    final label = '${width.toInt()}px / ${scale * 100}%';

    testWidgets('assessment identity and sample action remain readable at $label', (tester) async {
      setScreen(tester, Size(width, 844), textScale: scale);
      await tester.pumpWidget(testApp(const AssessmentInputScreen()));
      await tester.pumpAndSettle();
      final identity = find.textContaining('Patient P-');
      expect(identity, findsOneWidget);
      expectUnbrokenWord(tester, identity, 0, 7);
      final idText = tester.widget<Text>(identity).data!;
      expectUnbrokenWord(tester, identity, 8, idText.length);
      final sample = find.text('Use sample values');
      if (scale == 2) {
        expect(tester.getRect(sample).top, greaterThan(tester.getRect(identity).bottom));
      }
      await tester.ensureVisible(sample);
      await tester.tap(sample);
      await tester.pumpAndSettle();
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.text('Ready to assess'), findsOneWidget);
      expect(find.text(idText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('result identity and Moderate Risk have usable width at $label', (tester) async {
      setScreen(tester, Size(width, 844), textScale: scale);
      final assessment = PatientRepository().byId('P-0014')!.latest!;
      await tester.pumpWidget(testApp(ResultScreen(assessment: assessment)));
      await tester.pumpAndSettle();
      final identity = find.text('Patient ${assessment.patientId}');
      expectUnbrokenWord(tester, identity, 8, 8 + assessment.patientId.length);
      final risk = find.text('Moderate Risk');
      if (scale == 2) {
        // The heading gets the card's full content width; the icon no longer
        // consumes space alongside it. Actual browser fonts are checked live.
        expect(tester.getSize(risk).width, greaterThanOrEqualTo(270));
        expect(tester.getRect(find.text('Saved')).top, greaterThan(tester.getRect(identity).bottom));
        expect(tester.getSize(identity).width, greaterThan(200));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings control stacks without fragmenting labels at $label', (tester) async {
      setScreen(tester, Size(width, 844), textScale: scale);
      var changes = 0;
      await tester.pumpWidget(testApp(Scaffold(
        body: ListView(padding: const EdgeInsets.all(24), children: [
          SettingsGroup(children: [
            SettingsRow(
              icon: Icons.bloodtype_outlined,
              title: 'Blood Glucose',
              subtitle: 'Display and entry unit',
              trailing: SegmentedToggle<String>(
                options: const ['mmol/L', 'mg/dL'],
                selected: 'mmol/L',
                onChanged: (_) => changes++,
                labelOf: (value) => value,
              ),
            ),
          ]),
        ]),
      )));
      await tester.pumpAndSettle();
      expectUnbrokenWord(tester, find.text('Blood Glucose'), 6, 13);
      expectUnbrokenWord(tester, find.text('Display and entry unit'), 0, 7);
      if (width == 320) {
        expect(tester.getRect(find.text('mmol/L')).top,
            greaterThan(tester.getRect(find.text('Display and entry unit')).bottom));
      }
      await tester.tap(find.text('mg/dL'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('patient body retains the complete ID after transient messages at $label', (tester) async {
      setScreen(tester, Size(width, 844), textScale: scale);
      final repo = PatientRepository();
      final original = repo.byId('P-0014')!;
      final Assessment latest = original.latest!;
      await tester.pumpWidget(testApp(const PatientProfileScreen(patientId: 'P-0014'), repository: repo));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      final bodyId = find.descendant(of: find.byType(ListView).first, matching: find.text('Patient P-0014'));
      await tester.ensureVisible(bodyId);
      expectUnbrokenWord(tester, bodyId, 8, 14);
      expect(repo.byId('P-0014'), same(original));
      expect(repo.byId('P-0014')!.latest, same(latest));
      expect(tester.takeException(), isNull);
    });
  }
}
