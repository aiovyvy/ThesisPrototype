// Opt-in real socket test; owns only its temporary loopback backend on 18001.
import 'dart:convert';
import 'dart:io';

import 'package:aiovy/services/research_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

void main() {
  test('research client retries after real connection refusal and backend startup', () async {
    final probe = IOClient(HttpClient());
    final client = ResearchDemoClient(baseUrl: Uri.parse('http://127.0.0.1:18001'), client: IOClient(HttpClient()));
    Process? server;
    final serverLog = StringBuffer();
    addTearDown(() async {
      client.close();
      probe.close();
      server?.kill();
      if (server != null) await server.exitCode.timeout(const Duration(seconds: 10));
    });
    // Abort if somebody already owns the temporary test port.
    try {
      await probe.get(Uri.parse('http://127.0.0.1:18001/health'));
      fail('Temporary live-test port 18001 is already in use');
    } on http.ClientException {/* expected: backend is stopped */}
    await expectLater(client.load('R1'), throwsA(isA<ResearchConnectionException>()));
    server = await Process.start(
      File('ml_model/uci/.venv/Scripts/python.exe').absolute.path,
      ['-B', '-m', 'uvicorn', 'ml_model.research_demo.main:app', '--host', '127.0.0.1', '--port', '18001'],
      workingDirectory: Directory.current.path,
      environment: {'PYTHONDONTWRITEBYTECODE': '1'},
    );
    server.stdout.transform(utf8.decoder).listen(serverLog.write);
    server.stderr.transform(utf8.decoder).listen(serverLog.write);
    var ready = false;
    for (var i = 0; i < 100; i++) {
      try {
        final response = await probe.get(Uri.parse('http://127.0.0.1:18001/health'));
        if (response.statusCode == 200) {
          ready = true;
          break;
        }
      } on http.ClientException {/* wait for startup */}
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(ready, isTrue, reason: serverLog.toString());
    // Same client and example, with a new real HTTP request; no cached fallback.
    final recovered = await client.load('R1');
    expect(recovered.prediction, 'high risk');
    expect(recovered.probabilities['high risk'], 1);
  }, skip: !const bool.fromEnvironment('LIVE_RESEARCH_TEST'));
}
