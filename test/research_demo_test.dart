import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aiovy/data/repositories/app_settings.dart';
import 'package:aiovy/data/repositories/patient_repository.dart';
import 'package:aiovy/screens/research/research_demo_screen.dart';
import 'package:aiovy/screens/settings/settings_screen.dart';
import 'package:aiovy/services/research_demo_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/test_app.dart';
import 'helpers/research_fixtures.dart';

Future<void> screenshot(WidgetTester tester, GlobalKey boundary, String name) async {
  const output = String.fromEnvironment('RESEARCH_SCREENSHOTS');
  if (output.isEmpty) return;
  final render = tester.renderObject(find.byKey(boundary)) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(output).createSync(recursive: true);
    File('$output/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadTestFonts);

  test('six fixed examples use independent GET-only service and correct classes', () async {
    final requests = <http.Request>[];
    final client = fixedClient(requests: requests);
    addTearDown(client.close);
    for (final id in ResearchDemoClient.exampleIds) {
      final result = await client.load(id);
      final expected = fixtures().firstWhere((e) => e['example_id'] == id);
      expect(result.id, id);
      expect(result.datasetLabel, expected['dataset_label']);
      expect(result.prediction, expected['prediction']);
      expect(result.probabilities, expected['probabilities']);
      expect(result.contributions, expected['shap']['contributions']);
      expect(result.baseValue, expected['shap']['base_value']);
      expect(result.inputs.keys.toList(), ResearchExample.features);
      expect(result.probabilities.values.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(result.baseValue + result.contributions.values.reduce((a, b) => a + b),
          closeTo(result.probabilities[result.prediction]!, 1e-6));
    }
    expect(requests.length, 6);
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.url.host, 'research.local');
      expect(request.url.port, 8001);
      expect(request.url.query, isEmpty);
      expect(request.body, isEmpty);
    }
    expect(await client.load('R2').then((r) => r.prediction), 'mid risk');
    expect(await client.load('R3').then((r) => r.prediction), 'low risk');
    expect(await client.load('R6').then((r) => r.prediction), 'high risk');
  });

  test('arbitrary IDs are rejected before sending any request', () async {
    final requests = <http.Request>[];
    final client = fixedClient(requests: requests);
    addTearDown(client.close);
    await expectLater(client.load('patient-123'), throwsArgumentError);
    expect(requests, isEmpty);
  });

  test('wrong model, classes, units, probabilities and SHAP fail closed', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (b) => b['model_id'] = 'uci',
      (b) => b['example_id'] = 'R2',
      (b) => b['split'] = 'training',
      (b) => b['prediction'] = 'moderate',
      (b) => b['feature_units']['blood_glucose_mmol_l'] = 'mg/dL',
      (b) => b['feature_units']['body_temperature_c'] = 'Fahrenheit',
      (b) => b['model_inputs']['blood_glucose_mmol_l'] /= 18,
      (b) => b['model_inputs']['body_temperature_c'] = 97.5,
      (b) => b['probabilities']['high risk'] = -0.1,
      (b) => b['probabilities']['high risk'] = double.nan,
      (b) => b['probabilities']['high risk'] = 0.5,
      (b) => b['shap']['explained_class'] = 'low risk',
      (b) => b['shap']['base_value'] += 0.1,
      (b) => b['shap']['contributions'].remove('age'),
    ];
    for (final mutate in mutations) {
      final body = fixtures().first;
      mutate(body);
      expect(() => ResearchExample.parse(body, expectedId: 'R1'), throwsFormatException);
    }
  });

  testWidgets('fixed results and SHAP never call UCI or alter patient records', (tester) async {
    setScreen(tester, const Size(390, 844));
    final repository = PatientRepository();
    final classifier = FakeApiClassifier();
    final patientCount = repository.patients.length;
    final assessmentCount = repository.patients.fold(0, (n, p) => n + p.assessments.length);
    final settings = AppSettings()..glucoseUnit = GlucoseUnit.mgdL;
    final client = fixedClient();
    final boundary = GlobalKey();
    addTearDown(client.close);
    await tester.pumpWidget(testApp(ResearchDemoScreen(client: client),
        repository: repository, settings: settings, classifier: classifier, boundaryKey: boundary));
    await tester.pumpAndSettle();
    expect(find.text('Experimental research model'), findsOneWidget);
    expect(find.text('Demonstration only. Must not be used for clinical decisions.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Dataset label'), findsOneWidget);
    expect(find.text('Model prediction'), findsOneWidget);
    await tester.tap(find.text('Example R2'));
    await tester.pumpAndSettle();
    await screenshot(tester, boundary, 'research_result');
    expect(find.text('Prediction differs from the supplied dataset label.'), findsOneWidget);
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Fixed measurements · read only'), 180, scrollable: list);
    expect(find.text('6.6 mmol/L (provisional)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('SHAP explanation · Moderate Risk'), 180, scrollable: list);
    expect(find.text('SHAP explanation · Moderate Risk'), findsOneWidget);
    await tester.drag(list, const Offset(0, -150));
    await tester.pumpAndSettle();
    await screenshot(tester, boundary, 'research_shap');
    await tester.scrollUntilVisible(find.text('Research limitations'), 250, scrollable: list);
    expect(find.textContaining('not clinically verified outcomes'), findsOneWidget);
    // Warning stays visible even at the end of the explanation.
    expect(find.text('Experimental research model').hitTestable(), findsOneWidget);
    expect(repository.patients.length, patientCount);
    expect(repository.sessionAssessmentCount, 0);
    expect(repository.patients.fold(0, (n, p) => n + p.assessments.length), assessmentCount);
    expect(classifier.calls, 0);
    expect(settings.glucoseUnit, GlucoseUnit.mgdL);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings exposes research entry without switching classifier', (tester) async {
    setScreen(tester, const Size(390, 844));
    final classifier = FakeApiClassifier();
    await tester.pumpWidget(testApp(const SettingsScreen(), classifier: classifier));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Research Demonstration'), 250);
    expect(find.text('Experimental research model · six fixed examples only'), findsOneWidget);
    await tester.tap(find.text('Research Demonstration'));
    await tester.pumpAndSettle();
    expect(find.byType(ResearchDemoScreen), findsOneWidget);
    expect(find.text('Experimental research model'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(classifier.calls, 0);
  });

  testWidgets('research results support narrow screens and enlarged text', (tester) async {
    setScreen(tester, const Size(320, 700), textScale: 1.5);
    final client = fixedClient();
    addTearDown(client.close);
    await tester.pumpWidget(testApp(ResearchDemoScreen(client: client)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Research limitations'), 250);
    expect(find.text('Experimental research model').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('service errors keep warning and show no substitute prediction', (tester) async {
    setScreen(tester, const Size(360, 780), textScale: 1.3);
    final client = ResearchDemoClient(client: MockClient((_) async => http.Response('{}', 503)));
    addTearDown(client.close);
    await tester.pumpWidget(testApp(ResearchDemoScreen(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('Research service unavailable'), findsOneWidget);
    expect(find.text('Experimental research model'), findsOneWidget);
    expect(find.text('Model prediction'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Retry makes a new request and replaces connection error with validated output', (tester) async {
    setScreen(tester, const Size(390, 844));
    var attempts = 0;
    final client = ResearchDemoClient(
        baseUrl: Uri.parse('http://127.0.0.1:8001'),
        client: MockClient((request) async {
          attempts++;
          if (attempts == 1) throw http.ClientException('Connection refused');
          return http.Response(jsonEncode(fixtures().first), 200);
        }));
    addTearDown(client.close);
    await tester.pumpWidget(testApp(ResearchDemoScreen(client: client)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not connect to the research backend at http://127.0.0.1:8001'), findsOneWidget);
    expect(find.text('Model prediction'), findsNothing);
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Research service unavailable'), findsNothing);
    expect(find.text('Model prediction'), findsOneWidget);
    expect(find.text('Experimental research model'), findsOneWidget);
  });

  for (final size in [const Size(390, 1000), const Size(820, 1180), const Size(1440, 1150)]) {
    testWidgets('research responsive layout ${size.width.toInt()}px and accessible probabilities', (tester) async {
      setScreen(tester, size);
      final semantics = tester.ensureSemantics();
      final client = fixedClient();
      addTearDown(client.close);
      final boundary = GlobalKey();
      await tester.pumpWidget(testApp(ResearchDemoScreen(client: client, exampleId: 'R2'), boundaryKey: boundary));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Low Risk probability'), findsOneWidget);
      expect(find.bySemanticsLabel('Moderate Risk probability'), findsOneWidget);
      expect(find.bySemanticsLabel('High Risk probability'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      if (size.width >= 1000) {
        expect(tester.getSize(find.byKey(const ValueKey('research-wide-layout'))).width, greaterThan(1000));
        expect(tester.getTopLeft(find.text('SHAP explanation · Moderate Risk')).dx,
            greaterThan(tester.getTopLeft(find.text('Model probabilities')).dx + 400));
      } else {
        expect(find.byKey(const ValueKey('research-wide-layout')), findsNothing);
      }
      await screenshot(tester, boundary, 'research_${size.width.toInt()}px');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
