import 'dart:convert';
import 'dart:io';
import 'package:aiovy/services/research_demo_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Real six-example responses, independently checked by the Python artifact tests.
List<Map<String, dynamic>> fixtures() =>
    (jsonDecode(File('test/fixtures/research_examples.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();

ResearchDemoClient fixedClient({List<http.Request>? requests}) => ResearchDemoClient(
      baseUrl: Uri.parse('http://research.local:8001'),
      client: MockClient((request) async {
        requests?.add(request);
        final body = fixtures().firstWhere((e) => e['example_id'] == request.url.pathSegments.last);
        return http.Response(jsonEncode(body), 200);
      }),
    );
