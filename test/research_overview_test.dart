import 'dart:convert';
import 'dart:io';
import 'package:aiovy/core/constants/app_strings.dart';

import 'package:aiovy/data/research_overview.dart';
import 'package:aiovy/screens/research/research_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

// The saved evaluation CSVs contain plain unquoted fields. Read the locked
// predictions rather than treating copied metric strings as the test oracle.
List<Map<String, String>> csv(String path) {
  final lines = File(path).readAsLinesSync().where((line) => line.isNotEmpty).toList();
  final columns = lines.first.split(',');
  return [for (final line in lines.skip(1)) Map.fromIterables(columns, line.split(','))];
}

String percent(num value) => '${(value * 100).toStringAsFixed(1)}%';

void main() {
  setUpAll(loadTestFonts);

  test('informational metrics agree with metadata, CSV reports and locked predictions', () {
    const directories = ['ml_model/uci/reports/final_model', 'ml_model/reports/notebook_04'];
    const keys = {'Accuracy': 'accuracy', 'Macro F1': 'macro_f1', 'High-risk recall': 'high_risk_recall'};
    const csvKeys = {'Accuracy': 'Accuracy', 'Macro F1': 'Macro F1', 'High-risk recall': 'High-Risk Recall'};
    for (var index = 0; index < directories.length; index++) {
      final directory = directories[index];
      final metadata = jsonDecode(File('$directory/experiment_metadata.json').readAsStringSync()) as Map;
      final rows = csv('$directory/heldout_test_predictions.csv');
      final report = csv('$directory/heldout_test_metrics.csv').single;
      final actual = rows.map((r) => r['actual_risk']!).toList();
      final predicted = rows.map((r) => r['predicted_risk']!).toList();
      final correct = rows.where((r) => r['actual_risk'] == r['predicted_risk']).length;
      final high = rows.where((r) => r['actual_risk'] == 'high risk').toList();
      final detected = high.where((r) => r['predicted_risk'] == 'high risk').length;
      var macroF1 = 0.0;
      for (final label in ['low risk', 'mid risk', 'high risk']) {
        var tp = 0;
        var fp = 0;
        var fn = 0;
        for (var i = 0; i < rows.length; i++) {
          if (actual[i] == label && predicted[i] == label) tp++;
          if (actual[i] != label && predicted[i] == label) fp++;
          if (actual[i] == label && predicted[i] != label) fn++;
        }
        macroF1 += 2 * tp / (2 * tp + fp + fn) / 3;
      }
      final recomputed = {'Accuracy': correct / rows.length, 'Macro F1': macroF1, 'High-risk recall': detected / high.length};
      expect(rows.length, metadata['test_records']);
      expect(metadata['training_records'] + metadata['test_records'], metadata['dataset_records']);
      for (final entry in recomputed.entries) {
        final saved = metadata['test_metrics'][keys[entry.key]] as num;
        expect(entry.value, closeTo(saved.toDouble(), 1e-12));
        expect(entry.value, closeTo(double.parse(report[csvKeys[entry.key]]!), 1e-12));
        expect(ResearchOverview.models[index].metrics[entry.key], percent(saved));
        expect(File('README.md').readAsStringSync(), contains(percent(saved)));
      }
      if (index == 0) {
        expect(high.length, 23);
        expect(high.length - detected, 8);
      }
    }
    final selection = jsonDecode(File('ml_model/uci/reports/model_selection.json').readAsStringSync()) as Map;
    expect(selection['selected_model'], 'Random Forest');
    expect(selection['rule'], contains('high-risk recall'));
    expect(selection['rule'], contains('macro F1'));
  });

  for (final size in [const Size(320, 568), const Size(820, 1180), const Size(1440, 1000)]) {
    testWidgets('overview communicates boundaries without placeholders at ${size.width}px', (tester) async {
      setScreen(tester, size, textScale: size.width == 320 ? 1.5 : 1);
      await tester.pumpWidget(testApp(const ResearchScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('How AIOVY Works'), findsOneWidget);
      expect(find.text('UCI assessment prototype'), findsOneWidget);
      expect(find.text('Research Demonstration'), findsOneWidget);
      for (final model in ResearchOverview.models) {
        for (final value in model.metrics.values) {
          expect(find.text(value), findsWidgets);
        }
      }
      final text = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join('\n');
      expect(text, contains('Only Random Forest is integrated'));
      expect(text, contains('not clinically verified outcomes'));
      expect(text, contains('not medical causation'));
      expect(text, contains(AppStrings.researchDisclaimer));
      expect(text, contains('without converting glucose'));
      expect(text, contains('not a representative evaluation sample'));
      expect(text, contains('no measurement entry or save-to-history option'));
      for (final obsolete in ['Pending Evaluation', 'Placeholder', 'Protocol ID', 'Global Feature Importance', 'Model Comparison']) {
        expect(text, isNot(contains(obsolete)));
      }
      await tester.scrollUntilVisible(find.text('Sources behind this prototype'), 400,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }
}
