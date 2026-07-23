import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wiro_ai/wiro_ai.dart';
import 'package:test/test.dart';

void main() {
  group('WiroClient', () {
    test('rejects an empty API key', () {
      expect(() => WiroClient(apiKey: ''), throwsArgumentError);
    });

    test('searches models with API key authentication', () async {
      final httpClient = MockClient((request) async {
        expect(request.url.path, '/v1/Tool/List');
        expect(request.headers['x-api-key'], 'test-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['search'], 'video');
        expect(body['limit'], '10');

        return http.Response('{"toolboxdata":[]}', 200);
      });
      final client = WiroClient(apiKey: 'test-key', httpClient: httpClient);

      final response = await client.searchModels(search: 'video', limit: 10);

      expect(response['toolboxdata'], isEmpty);
      client.close();
    });

    test('rejects an invalid model slug', () {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(() => client.getModelSchema('invalid'), throwsArgumentError);
      client.close();
    });

    test('throws WiroApiException for an API error', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((_) async => http.Response('Unauthorized', 401)),
      );

      await expectLater(
        client.explore(),
        throwsA(
          isA<WiroApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      client.close();
    });
  });
}
