import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:wiro_client/wiro_client.dart';

void main() {
  group('WiroClient configuration', () {
    test('rejects an empty API key', () {
      expect(() => WiroClient(apiKey: ''), throwsArgumentError);
    });

    test('rejects an empty API secret', () {
      expect(
        () => WiroClient(apiKey: 'key', apiSecret: '  '),
        throwsArgumentError,
      );
    });

    test('rejects invalid timeout and polling values', () {
      expect(
        () => WiroClient(
          apiKey: 'key',
          requestTimeout: Duration.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => WiroClient(
          apiKey: 'key',
          pollInterval: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects unsafe base URI shapes', () {
      for (final uri in [
        Uri.parse('ftp://api.wiro.ai/v1'),
        Uri.parse('https://key@api.wiro.ai/v1'),
        Uri.parse('https://api.wiro.ai/v1?key=value'),
        Uri.parse('https://api.wiro.ai/v1#fragment'),
      ]) {
        expect(
          () => WiroClient(apiKey: 'key', baseUri: uri),
          throwsArgumentError,
        );
      }
    });

    test('rejects unsafe WebSocket URI shapes', () {
      for (final uri in [
        Uri.parse('https://socket.wiro.ai/v1'),
        Uri.parse('wss://key@socket.wiro.ai/v1'),
        Uri.parse('wss://socket.wiro.ai/v1?key=value'),
        Uri.parse('wss://socket.wiro.ai/v1#fragment'),
      ]) {
        expect(
          () => WiroClient(apiKey: 'key', socketUri: uri),
          throwsArgumentError,
        );
      }
    });

    test('uses API key authentication', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.headers['x-api-key'], 'test-key');
          expect(request.headers['x-signature'], isNull);
          return _jsonResponse(_emptyExploreResponse);
        }),
      );

      expect(client.authType, WiroAuthType.apiKey);
      await client.explore();
      client.close();
    });

    test('generates a valid signature', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        apiSecret: 'test-secret',
        httpClient: MockClient((request) async {
          final nonce = request.headers['x-nonce'];
          final signature = request.headers['x-signature'];
          expect(nonce, isNotNull);
          final expected = Hmac(
            sha256,
            utf8.encode('test-key'),
          ).convert(utf8.encode('test-secret$nonce'));
          expect(signature, '$expected');
          return _jsonResponse(_emptyExploreResponse);
        }),
      );

      expect(client.authType, WiroAuthType.signature);
      await client.explore();
      client.close();
    });
  });

  group('WiroClient model APIs', () {
    test('searches models with typed pagination', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/Tool/List');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['search'], 'image');
          expect(body['limit'], '10');
          return _jsonResponse(_modelListResponse);
        }),
      );

      final response = await client.searchModels(
        search: 'image',
        limit: 10,
      );

      expect(response.total, 1);
      expect(
        response.items.single.identifier,
        'black-forest-labs/flux-2-pro',
      );
    });

    test('validates pagination bounds', () {
      final client = WiroClient(apiKey: 'test-key');

      expect(
        () => client.searchModels(start: -1),
        throwsArgumentError,
      );
      expect(
        () => client.searchModels(limit: 0),
        throwsArgumentError,
      );
      expect(
        () => client.searchModels(limit: 101),
        throwsArgumentError,
      );
      client.close();
    });

    test('returns a typed model schema', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient(
          (_) async => _jsonResponse(_modelSchemaResponse),
        ),
      );

      final schema = await client.getModelSchema(
        'black-forest-labs/flux-2-pro',
      );

      expect(schema.model.identifier, 'black-forest-labs/flux-2-pro');
      expect(schema.parameters.single.id, 'prompt');
    });

    test('runs a model with dynamic parameters', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/v1/Run/black-forest-labs/flux-2-pro',
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['prompt'], 'A mountain');
          expect(body['callbackUrl'], 'https://example.com/wiro');
          return _jsonResponse(_runResponse);
        }),
      );

      final result = await client.runModel(
        'black-forest-labs/flux-2-pro',
        parameters: {'prompt': 'A mountain'},
        callbackUrl: Uri.parse('https://example.com/wiro'),
      );

      expect(result.taskId, '42');
      expect(result.taskToken, 'task-token');
    });

    test('rejects an invalid callback URL', () {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((_) async => _jsonResponse(_runResponse)),
      );

      expect(
        () => client.runModel(
          'black-forest-labs/flux-2-pro',
          callbackUrl: Uri.parse('file:///tmp/callback'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an invalid model slug', () {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((_) async => _jsonResponse(const {})),
      );

      expect(
        () => client.getModelSchema('invalid'),
        throwsArgumentError,
      );
      expect(
        () => client.getModelSchema('owner/model/extra'),
        throwsArgumentError,
      );
      expect(
        () => client.getModelSchema('../model'),
        throwsArgumentError,
      );
    });
  });

  group('WiroClient task APIs', () {
    test('subscribes to a model until it succeeds', () async {
      var detailRequestCount = 0;
      final updates = <WiroTask>[];
      final client = WiroClient(
        apiKey: 'test-key',
        pollInterval: Duration.zero,
        httpClient: MockClient((request) async {
          if (request.url.path == '/v1/Run/wiro/demo') {
            return _jsonResponse(_runResponse);
          }
          detailRequestCount++;
          return _jsonResponse(
            detailRequestCount == 1
                ? _runningTaskResponse
                : _completedTaskResponse,
          );
        }),
      );

      final task = await client.subscribe(
        'wiro/demo',
        onTaskUpdate: updates.add,
      );

      expect(task.isSuccessful, isTrue);
      expect(
        updates.map((task) => task.status),
        [WiroTaskStatus.running, WiroTaskStatus.completed],
      );
    });

    test('throws a typed exception for a failed subscription', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        pollInterval: Duration.zero,
        httpClient: MockClient((request) async {
          return _jsonResponse(
            request.url.path.startsWith('/v1/Run')
                ? _runResponse
                : _failedTaskResponse,
          );
        }),
      );

      await expectLater(
        client.subscribe('wiro/demo'),
        throwsA(
          isA<WiroTaskFailedException>()
              .having(
                (error) => error.task.exitCode,
                'task.exitCode',
                '1',
              )
              .having(
                (error) => error.task.debugOutput,
                'task.debugOutput',
                'Model failed',
              ),
        ),
      );
    });

    test('can return a failed subscription task', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        pollInterval: Duration.zero,
        httpClient: MockClient((request) async {
          return _jsonResponse(
            request.url.path.startsWith('/v1/Run')
                ? _runResponse
                : _failedTaskResponse,
          );
        }),
      );

      final task = await client.subscribe(
        'wiro/demo',
        throwOnTaskFailure: false,
      );

      expect(task.isFinished, isTrue);
      expect(task.isSuccessful, isFalse);
    });

    test('gets task details by token', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['tasktoken'], 'task-token');
          return _jsonResponse(_completedTaskResponse);
        }),
      );

      final task = await client.getTask(taskToken: 'task-token');

      expect(task.status, WiroTaskStatus.completed);
      expect(task.isSuccessful, isTrue);
    });

    test('requires a token or an ID', () {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((_) async => _jsonResponse(const {})),
      );

      expect(client.getTask, throwsArgumentError);
      expect(
        () => client.getTask(taskToken: ' '),
        throwsArgumentError,
      );
    });

    test('waits until the task is terminal', () async {
      var requestCount = 0;
      final client = WiroClient(
        apiKey: 'test-key',
        pollInterval: Duration.zero,
        httpClient: MockClient((_) async {
          requestCount++;
          return _jsonResponse(
            requestCount == 1 ? _runningTaskResponse : _completedTaskResponse,
          );
        }),
      );

      final task = await client.waitForTask('task-token');

      expect(task.status, WiroTaskStatus.completed);
      expect(requestCount, 2);
    });

    test('streams task status changes', () async {
      var requestCount = 0;
      final client = WiroClient(
        apiKey: 'test-key',
        pollInterval: Duration.zero,
        httpClient: MockClient((_) async {
          requestCount++;
          return _jsonResponse(
            requestCount == 1 ? _runningTaskResponse : _completedTaskResponse,
          );
        }),
      );

      final tasks = await client.watchTask('task-token').toList();

      expect(
        tasks.map((task) => task.status),
        [WiroTaskStatus.running, WiroTaskStatus.completed],
      );
    });

    test('throws when task polling times out', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        pollInterval: const Duration(milliseconds: 2),
        httpClient: MockClient(
          (_) async => _jsonResponse(_runningTaskResponse),
        ),
      );

      await expectLater(
        client.waitForTask(
          'task-token',
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(isA<WiroTimeoutException>()),
      );
    });

    test('rejects invalid task polling values', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((_) async {
          return _jsonResponse(_runningTaskResponse);
        }),
      );

      await expectLater(
        client.watchTask(' ').toList(),
        throwsArgumentError,
      );
      await expectLater(
        client.watchTask('task-token', timeout: Duration.zero).toList(),
        throwsArgumentError,
      );
    });

    test('cancels and kills tasks', () async {
      final paths = <String>[];
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          return _jsonResponse(const {'result': true});
        }),
      );

      expect(await client.cancelTask('task-token'), isTrue);
      expect(await client.killTask('task-token'), isTrue);
      expect(paths, ['/v1/Task/Cancel', '/v1/Task/Kill']);
    });
  });

  group('WiroClient task WebSocket', () {
    test('rejects invalid socket watch values', () async {
      final client = WiroClient(apiKey: 'test-key');

      await expectLater(
        client.watchTaskSocket(' ').toList(),
        throwsArgumentError,
      );
      await expectLater(
        client
            .watchTaskSocket(
              'task-token',
              timeout: Duration.zero,
            )
            .toList(),
        throwsArgumentError,
      );
      client.close();
    });

    test(
      'streams typed lifecycle, progress, and final output events',
      () async {
        final server = await _SocketTestServer.start((socket) async {
          final registration =
              jsonDecode(await socket.first as String) as Map<String, dynamic>;
          expect(registration['type'], 'task_info');
          expect(registration['tasktoken'], 'task-token');

          socket
            ..add(jsonEncode(_socketEvent('task_queue')))
            ..add(
              jsonEncode(
                _socketEvent(
                  'task_output',
                  message: const {
                    'type': 'progressGenerate',
                    'percentage': '60',
                    'stepCurrent': '6',
                    'stepTotal': '10',
                  },
                ),
              ),
            )
            ..add(
              jsonEncode(
                _socketEvent(
                  'task_postprocess_end',
                  message: const [
                    {
                      'name': 'result.png',
                      'contenttype': 'image/png',
                      'url': 'https://cdn.wiro.ai/result.png',
                    },
                  ],
                ),
              ),
            );
        });
        addTearDown(server.close);
        final client = WiroClient(
          apiKey: 'test-key',
          socketUri: server.uri,
        );

        final events = await client.watchTaskSocket('task-token').toList();
        final messages = events.whereType<WiroSocketMessageEvent>().toList();

        expect(
          messages.map((event) => event.status),
          [
            WiroTaskStatus.queued,
            WiroTaskStatus.output,
            WiroTaskStatus.completed,
          ],
        );
        expect(messages[1].progress?.percentage, 60);
        expect(messages[1].progress?.currentStep, 6);
        expect(messages.last.outputs.single.name, 'result.png');
        expect(messages.last.isTerminal, isTrue);
        await server.done;
      },
    );

    test('emits binary frames from realtime tasks', () async {
      final server = await _SocketTestServer.start((socket) async {
        await socket.first;
        socket
          ..add(const [1, 2, 3])
          ..add(jsonEncode(_socketEvent('task_cancel', result: false)));
      });
      addTearDown(server.close);
      final client = WiroClient(
        apiKey: 'test-key',
        socketUri: server.uri,
      );

      final events = await client.watchTaskSocket('task-token').toList();

      expect(
        (events.first as WiroSocketBinaryEvent).bytes,
        [1, 2, 3],
      );
      expect(
        (events.last as WiroSocketMessageEvent).status,
        WiroTaskStatus.cancelled,
      );
      await server.done;
    });

    test('supports socket cancellation', () async {
      final registered = Completer<void>();
      final releaseServer = Completer<void>();
      final server = await _SocketTestServer.start((socket) async {
        await socket.first;
        registered.complete();
        await releaseServer.future;
      });
      addTearDown(server.close);
      final cancellationToken = WiroCancellationToken();
      final client = WiroClient(
        apiKey: 'test-key',
        socketUri: server.uri,
      );

      final events = client
          .watchTaskSocket(
            'task-token',
            cancellationToken: cancellationToken,
          )
          .toList();
      await registered.future;
      cancellationToken.cancel();

      await expectLater(
        events,
        throwsA(isA<WiroRequestCancelledException>()),
      );
      releaseServer.complete();
      await server.done;
    });

    test('times out a socket stream without a terminal event', () async {
      final releaseServer = Completer<void>();
      final server = await _SocketTestServer.start((socket) async {
        await socket.first;
        await releaseServer.future;
      });
      addTearDown(server.close);
      final client = WiroClient(
        apiKey: 'test-key',
        socketUri: server.uri,
      );

      await expectLater(
        client
            .watchTaskSocket(
              'task-token',
              timeout: const Duration(milliseconds: 10),
            )
            .toList(),
        throwsA(isA<WiroTimeoutException>()),
      );
      releaseServer.complete();
      await server.done;
    });

    test('maps invalid socket JSON to a typed exception', () async {
      final server = await _SocketTestServer.start((socket) async {
        await socket.first;
        socket.add('invalid');
      });
      addTearDown(server.close);
      final client = WiroClient(
        apiKey: 'test-key',
        socketUri: server.uri,
      );

      await expectLater(
        client.watchTaskSocket('task-token').toList(),
        throwsA(isA<WiroWebSocketException>()),
      );
      await server.done;
    });
  });

  group('WiroClient upload', () {
    test('uploads bytes as multipart data', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient.streaming((request, bodyStream) async {
          expect(request.url.path, '/v1/File/Upload');
          expect(request.headers['content-type'], contains('multipart/form'));
          final body = utf8.decode(await bodyStream.toBytes());
          expect(body, contains('photo.png'));
          expect(body, contains('image-data'));
          return _streamedJsonResponse(_uploadResponse);
        }),
      );

      final result = await client.uploadFile(
        utf8.encode('image-data'),
        fileName: 'photo.png',
      );

      expect(result.files.single.name, 'photo.png');
    });

    test('uploads a byte stream as multipart data', () async {
      final bytes = utf8.encode('stream-data');
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient.streaming((request, bodyStream) async {
          final body = utf8.decode(await bodyStream.toBytes());
          expect(body, contains('stream.bin'));
          expect(body, contains('stream-data'));
          return _streamedJsonResponse(_uploadResponse);
        }),
      );

      final result = await client.uploadStream(
        Stream.value(bytes),
        contentLength: bytes.length,
        fileName: 'stream.bin',
      );

      expect(result.isSuccess, isTrue);
    });

    test('validates upload metadata', () {
      final client = WiroClient(apiKey: 'test-key');

      expect(
        () => client.uploadFile(const [], fileName: ' '),
        throwsArgumentError,
      );
      expect(
        () => client.uploadStream(
          const Stream.empty(),
          contentLength: -1,
          fileName: 'file.bin',
        ),
        throwsArgumentError,
      );
      client.close();
    });
  });

  group('WiroClient failures', () {
    test('maps application-level failures to a typed exception', () async {
      final events = <WiroLogEvent>[];
      final client = WiroClient(
        apiKey: 'test-key',
        logger: events.add,
        httpClient: MockClient(
          (_) async => _jsonResponse(
            const {
              'result': false,
              'errors': [
                {'code': 97, 'message': 'Insufficient balance'},
              ],
            },
          ),
        ),
      );

      await expectLater(
        client.runModel('wiro/demo'),
        throwsA(
          isA<WiroApiResultException>()
              .having((error) => error.code, 'code', 97)
              .having(
                (error) => error.message,
                'message',
                'Insufficient balance',
              ),
        ),
      );
      expect(
        events.where((event) => event.level == WiroLogLevel.error),
        hasLength(1),
      );
      expect(events.last.error, isNull);
    });

    for (final (statusCode, exceptionType) in [
      (400, WiroValidationException),
      (401, WiroAuthenticationException),
      (403, WiroAuthenticationException),
      (404, WiroUnknownApiException),
      (422, WiroValidationException),
      (429, WiroRateLimitException),
      (500, WiroUnknownApiException),
    ]) {
      test('maps $statusCode responses to $exceptionType', () async {
        final client = WiroClient(
          apiKey: 'test-key',
          retryPolicy: const WiroRetryPolicy.none(),
          httpClient: MockClient(
            (_) async => _jsonResponse(
              const {
                'result': false,
                'errors': [
                  {'message': 'Request failed'},
                ],
              },
              statusCode: statusCode,
              headers: statusCode == 429
                  ? const {'retry-after': '2'}
                  : const {},
            ),
          ),
        );

        await expectLater(
          client.explore(),
          throwsA(
            isA<WiroApiException>()
                .having(
                  (error) => error.runtimeType,
                  'runtimeType',
                  exceptionType,
                )
                .having(
                  (error) => error.statusCode,
                  'statusCode',
                  statusCode,
                ),
          ),
        );
      });
    }

    test('exposes retry-after on rate-limit errors', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        retryPolicy: const WiroRetryPolicy.none(),
        httpClient: MockClient(
          (_) async => _jsonResponse(
            const {'message': 'Slow down'},
            statusCode: 429,
            headers: const {'retry-after': '3'},
          ),
        ),
      );

      await expectLater(
        client.explore(),
        throwsA(
          isA<WiroRateLimitException>().having(
            (error) => error.retryAfter,
            'retryAfter',
            const Duration(seconds: 3),
          ),
        ),
      );
    });

    test('maps invalid JSON to an unknown API error', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((_) async => http.Response('invalid', 200)),
      );

      await expectLater(
        client.explore(),
        throwsA(isA<WiroUnknownApiException>()),
      );
    });

    test('maps client failures to a network error', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        retryPolicy: const WiroRetryPolicy.none(),
        httpClient: MockClient(
          (_) async => throw http.ClientException('offline'),
        ),
      );

      await expectLater(
        client.explore(),
        throwsA(isA<WiroNetworkException>()),
      );
    });

    test('times out an individual request', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        requestTimeout: const Duration(milliseconds: 1),
        retryPolicy: const WiroRetryPolicy.none(),
        httpClient: _abortableMockClient(),
      );

      await expectLater(
        client.explore(),
        throwsA(isA<WiroTimeoutException>()),
      );
    });

    test('cancels an individual request', () async {
      final cancellationToken = WiroCancellationToken();
      final client = WiroClient(
        apiKey: 'test-key',
        retryPolicy: const WiroRetryPolicy.none(),
        httpClient: _abortableMockClient(),
      );

      final request = client.explore(cancellationToken: cancellationToken);
      cancellationToken.cancel();

      await expectLater(
        request,
        throwsA(isA<WiroRequestCancelledException>()),
      );
    });
  });

  group('WiroClient retries and logging', () {
    test('does not retry model runs', () async {
      var requestCount = 0;
      final client = WiroClient(
        apiKey: 'test-key',
        retryPolicy: const WiroRetryPolicy(
          initialDelay: Duration.zero,
          maximumDelay: Duration.zero,
        ),
        httpClient: MockClient((_) async {
          requestCount++;
          return http.Response('Unavailable', 503);
        }),
      );

      await expectLater(
        client.runModel('wiro/demo'),
        throwsA(isA<WiroUnknownApiException>()),
      );
      expect(requestCount, 1);
    });

    test('does not retry model runs after network failures', () async {
      var requestCount = 0;
      final client = WiroClient(
        apiKey: 'test-key',
        retryPolicy: const WiroRetryPolicy(
          initialDelay: Duration.zero,
          maximumDelay: Duration.zero,
        ),
        httpClient: MockClient((_) async {
          requestCount++;
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        client.runModel('wiro/demo'),
        throwsA(isA<WiroNetworkException>()),
      );
      expect(requestCount, 1);
    });

    test('does not retry file uploads', () async {
      var requestCount = 0;
      final client = WiroClient(
        apiKey: 'test-key',
        retryPolicy: const WiroRetryPolicy(
          initialDelay: Duration.zero,
          maximumDelay: Duration.zero,
        ),
        httpClient: MockClient.streaming((request, bodyStream) async {
          requestCount++;
          await bodyStream.drain<void>();
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        client.uploadFile(const [1, 2, 3], fileName: 'file.bin'),
        throwsA(isA<WiroNetworkException>()),
      );
      expect(requestCount, 1);
    });

    test('retries transient status codes with backoff', () async {
      var requestCount = 0;
      final events = <WiroLogEvent>[];
      final client = WiroClient(
        apiKey: 'test-key',
        retryPolicy: const WiroRetryPolicy(
          maxRetries: 1,
          initialDelay: Duration.zero,
          maximumDelay: Duration.zero,
        ),
        logger: events.add,
        httpClient: MockClient((_) async {
          requestCount++;
          return requestCount == 1
              ? http.Response('Unavailable', 503)
              : _jsonResponse(_emptyExploreResponse);
        }),
      );

      await client.explore();

      expect(requestCount, 2);
      expect(
        events.where((event) => event.level == WiroLogLevel.warning),
        hasLength(1),
      );
      expect(
        events.every((event) => !event.message.contains('test-key')),
        isTrue,
      );
    });
  });
}

MockClient _abortableMockClient() {
  return MockClient.streaming((request, bodyStream) async {
    await bodyStream.drain<void>();
    final abortTrigger = (request as http.Abortable).abortTrigger;
    await abortTrigger;
    throw http.RequestAbortedException(request.url);
  });
}

http.Response _jsonResponse(
  Map<String, Object?> body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: headers,
  );
}

http.StreamedResponse _streamedJsonResponse(Map<String, Object?> body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
  );
}

const _emptyExploreResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'explore': <Object?>[],
};

const _modelListResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'total': '1',
  'tool': [
    {
      'id': '42',
      'title': 'FLUX.2 Pro',
      'cleanslugowner': 'black-forest-labs',
      'cleanslugproject': 'flux-2-pro',
      'categories': ['text-to-image'],
    },
  ],
};

const _modelSchemaResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'tool': [
    {
      'id': '42',
      'title': 'FLUX.2 Pro',
      'cleanslugowner': 'black-forest-labs',
      'cleanslugproject': 'flux-2-pro',
      'parameters': [
        {
          'title': 'Inputs',
          'items': [
            {
              'id': 'prompt',
              'type': 'textarea',
              'label': 'Prompt',
              'required': true,
            },
          ],
        },
      ],
    },
  ],
};

const _runResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'taskid': '42',
  'socketaccesstoken': 'task-token',
};

const _runningTaskResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'total': '1',
  'tasklist': [
    {
      'id': '42',
      'socketaccesstoken': 'task-token',
      'status': 'task_start',
      'outputs': <Object?>[],
    },
  ],
};

const _completedTaskResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'total': '1',
  'tasklist': [
    {
      'id': '42',
      'socketaccesstoken': 'task-token',
      'status': 'task_postprocess_end',
      'pexit': '0',
      'outputs': <Object?>[],
    },
  ],
};

const _failedTaskResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'total': '1',
  'tasklist': [
    {
      'id': '42',
      'socketaccesstoken': 'task-token',
      'status': 'task_postprocess_end',
      'pexit': '1',
      'debugoutput': 'Model failed',
      'outputs': <Object?>[],
    },
  ],
};

const _uploadResponse = <String, Object?>{
  'result': true,
  'errors': <Object?>[],
  'list': [
    {
      'id': 'file-1',
      'name': 'photo.png',
      'contenttype': 'image/png',
      'size': '10',
      'url': 'https://cdn.wiro.ai/photo.png',
    },
  ],
};

Map<String, Object?> _socketEvent(
  String type, {
  Object? message,
  bool result = true,
}) {
  return {
    'type': type,
    'id': '42',
    'tasktoken': 'task-token',
    'message': message,
    'result': result,
  };
}

final class _SocketTestServer {
  _SocketTestServer._({
    required HttpServer server,
    required this.done,
  }) : _server = server,
       uri = Uri.parse('ws://${server.address.address}:${server.port}');

  final HttpServer _server;
  final Future<void> done;
  final Uri uri;

  static Future<_SocketTestServer> start(
    Future<void> Function(WebSocket socket) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final done = Completer<void>();
    server.listen((request) async {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        await handler(socket);
        await socket.close();
        done.complete();
      } on Object catch (error, stackTrace) {
        done.completeError(error, stackTrace);
      }
    });
    return _SocketTestServer._(server: server, done: done.future);
  }

  Future<void> close() => _server.close(force: true);
}
