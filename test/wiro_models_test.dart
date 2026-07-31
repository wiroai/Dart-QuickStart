import 'package:test/test.dart';
import 'package:wiro_client/wiro_client.dart';

void main() {
  group('WiroModelId', () {
    test('creates and parses valid model identifiers', () {
      final created = WiroModelId('black-forest-labs', 'flux_2.pro');
      final parsed = WiroModelId.parse(created.value);

      expect(parsed.owner, 'black-forest-labs');
      expect(parsed.project, 'flux_2.pro');
      expect(parsed.toString(), 'black-forest-labs/flux_2.pro');
    });

    test('rejects invalid owner and project slugs', () {
      expect(() => WiroModelId('', 'model'), throwsArgumentError);
      expect(() => WiroModelId('owner', '-model'), throwsArgumentError);
      expect(() => WiroModelId.parse('owner/model/extra'), throwsArgumentError);
    });
  });

  group('WiroModelSchema', () {
    test('parses model metadata and parameters', () {
      final schema = WiroModelSchema.fromJson({
        'id': '1',
        'title': 'FLUX.2 Pro',
        'cleanslugowner': 'black-forest-labs',
        'cleanslugproject': 'flux-2-pro',
        'categories': ['text-to-image'],
        'parameters': [
          {
            'title': 'Inputs',
            'items': [
              {
                'id': 'outputFormat',
                'type': 'select',
                'label': 'Output format',
                'required': true,
                'options': [
                  {'label': 'PNG', 'value': 'png'},
                ],
              },
            ],
          },
        ],
      });

      expect(schema.model.modelId?.value, 'black-forest-labs/flux-2-pro');
      expect(schema.model.categories, ['text-to-image']);
      expect(schema.parameters.single.id, 'outputFormat');
      expect(schema.parameters.single.isRequired, isTrue);
      final parameter = schema.parameters.single as WiroSelectParameter;
      expect(parameter.options.single.value, 'png');
    });

    test('parses optional model metadata and task statistics', () {
      final model = WiroModel.fromJson({
        'id': 1,
        'slugowner': 'wiro',
        'slugproject': 'demo',
        'description': 'Demo model',
        'seodescription': 'SEO description',
        'image': 'https://cdn.wiro.ai/model.png',
        'tags': ['featured'],
        'samples': ['https://cdn.wiro.ai/sample.png'],
        'computingtime': '5',
        'approximatelycost': '0.1',
        'dynamicprice': 'true',
        'cps': '1',
        'taskstat': {
          'runcount': 10,
          'successcount': '8',
          'errorcount': '2',
          'lastruntime': '1774007585',
        },
      });

      expect(model.modelId?.value, 'wiro/demo');
      expect(model.imageUrl?.host, 'cdn.wiro.ai');
      expect(model.taskStats?.successCount, 8);
      expect(
        model.taskStats?.lastRunTime,
        DateTime.fromMillisecondsSinceEpoch(1774007585000, isUtc: true),
      );
      expect(model.tags, ['featured']);
    });

    test('returns no model identifier when slug fields are absent', () {
      final model = WiroModel.fromJson(const {'id': '1'});

      expect(model.modelId, isNull);
    });

    test('creates the sealed parameter variants', () {
      final parameters = [
        WiroModelParameter.fromJson(const {
          'id': 'choice',
          'type': 'select',
          'default': 'one',
          'options': [
            {'label': 'One', 'value': 'one'},
          ],
        }),
        WiroModelParameter.fromJson(const {
          'id': 'count',
          'type': 'range',
          'min': '1',
          'max': 10,
          'step': '0.5',
          'default': '0.5',
        }),
        WiroModelParameter.fromJson(const {
          'id': 'prompt',
          'type': 'textarea',
          'default': 'Describe an image',
        }),
        WiroModelParameter.fromJson(const {
          'id': 'inputs',
          'type': 'combinefileinput',
          'default': ['https://example.com/input.png'],
        }),
        WiroModelParameter.fromJson(const {
          'id': 'future',
          'type': 'future-input',
          'default': {'mode': 'future'},
        }),
      ];

      final select = parameters[0] as WiroSelectParameter;
      final number = parameters[1] as WiroNumberParameter;
      final text = parameters[2] as WiroTextParameter;
      final file = parameters[3] as WiroFileParameter;
      final unknown = parameters[4] as WiroUnknownParameter;

      expect(select.defaultValue, 'one');
      expect(number.defaultValue, 0.5);
      expect(text.defaultValue, 'Describe an image');
      expect(file.raw['default'], ['https://example.com/input.png']);
      expect(unknown.defaultValue, {'mode': 'future'});
      expect(unknown.raw['default'], same(unknown.defaultValue));
      expect(
        unknown,
        isA<WiroUnknownParameter>().having(
          (parameter) => parameter.type,
          'type',
          'future-input',
        ),
      );
      expect(number.minimum, 1);
      expect(number.maximum, 10);
      expect(number.step, 0.5);
    });

    test('validates required, select, and numeric parameters', () {
      final schema = WiroModelSchema.fromJson({
        'id': '1',
        'cleanslugowner': 'wiro',
        'cleanslugproject': 'validation',
        'parameters': [
          {
            'title': 'Inputs',
            'items': [
              {
                'id': 'format',
                'type': 'select',
                'required': true,
                'options': [
                  {'label': 'PNG', 'value': 'png'},
                ],
              },
              {'id': 'steps', 'type': 'range', 'min': 1, 'max': 10},
            ],
          },
        ],
      });

      // These calls intentionally exercise separate validation outcomes.
      // ignore: cascade_invocations
      schema.validate(const {'format': 'png', 'steps': 5});
      expect(
        () => schema.validate(const {'steps': 11}),
        throwsA(
          isA<WiroSchemaValidationException>()
              .having(
                (error) => error.message,
                'message',
                allOf(contains('format is required'), contains('at most 10.0')),
              )
              .having((error) => error.issues, 'issues', [
                'format is required',
                'steps must be at most 10.0',
              ])
              .having(
                (error) => error,
                'API exception',
                isNot(isA<WiroApiException>()),
              ),
        ),
      );
      expect(
        () => schema.validate(const {'format': 'jpeg', 'steps': 'many'}),
        throwsA(
          isA<WiroSchemaValidationException>().having(
            (error) => error.message,
            'message',
            allOf(contains('must be one of'), contains('must be numeric')),
          ),
        ),
      );
    });
  });

  group('WiroPaginatedResult', () {
    test('accepts string totals', () {
      final result = WiroPaginatedResult<WiroModel>.fromJson(
        {
          'result': true,
          'errors': <Object?>[],
          'total': '494',
          'tool': [
            {
              'id': '1',
              'cleanslugowner': 'wiro',
              'cleanslugproject': 'example',
            },
          ],
        },
        itemsKey: 'tool',
        itemFromJson: WiroModel.fromJson,
      );

      expect(result.isSuccess, isTrue);
      expect(result.total, 494);
      expect(result.items.single.modelId?.value, 'wiro/example');
    });
  });

  group('WiroRunResult', () {
    test('parses task identifiers', () {
      final result = WiroRunResult.fromJson({
        'result': true,
        'errors': <Object?>[],
        'taskid': '2221',
        'socketaccesstoken': 'task-token',
      });

      expect(result.isSuccess, isTrue);
      expect(result.taskId?.value, '2221');
      expect(result.taskToken?.value, 'task-token');
    });

    test('accepts a response without task references', () {
      final result = WiroRunResult.fromJson({
        'result': false,
        'errors': <Object?>[],
      });

      expect(result.taskId, isNull);
      expect(result.taskToken, isNull);
    });
  });

  group('WiroTask', () {
    test('parses status, parameters, and outputs', () {
      final task = WiroTask.fromJson({
        'id': '2221',
        'socketaccesstoken': 'task-token',
        'parameters': '{"prompt":"A mountain"}',
        'status': 'task_postprocess_end',
        'pexit': '0',
        'starttime': '2026-07-24 09:10:11',
        'endtime': '2026-07-24T09:10:14Z',
        'elapsedseconds': '3.5',
        'totalcost': '0.4',
        'outputs': [
          {
            'name': 'result.mp4',
            'contenttype': 'video/mp4',
            'size': '1024',
            'url': 'https://cdn.wiro.ai/result.mp4',
          },
        ],
      });

      expect(task.status, WiroTaskStatus.completed);
      expect(task.isSuccessful, isTrue);
      expect(task.parameters['prompt'], 'A mountain');
      expect(task.exitCode, 0);
      expect(task.startTime, DateTime(2026, 7, 24, 9, 10, 11));
      expect(task.endTime, DateTime.utc(2026, 7, 24, 9, 10, 14));
      expect(task.elapsed, const Duration(milliseconds: 3500));
      expect(task.outputs.single.size, 1024);
      expect(task.outputs.single.isVideo, isTrue);
      expect(task.outputs.single.url?.host, 'cdn.wiro.ai');
    });

    test('returns null for malformed timestamps and integer fields', () {
      final task = WiroTask.fromJson({
        'id': '1',
        'socketaccesstoken': 'task-token',
        'starttime': 'not-a-time',
        'endtime': <Object?>[],
        'pexit': 'not-an-integer',
        'elapsedseconds': 'not-a-duration',
        'outputs': [
          {'contenttype': 'image/png', 'size': 'unknown'},
        ],
      });
      final model = WiroModel.fromJson({
        'cleanslugowner': 'wiro',
        'cleanslugproject': 'demo',
        'taskstat': {'lastruntime': 'not-a-time'},
      });

      expect(task.startTime, isNull);
      expect(task.endTime, isNull);
      expect(task.exitCode, isNull);
      expect(task.elapsed, isNull);
      expect(task.outputs.single.size, isNull);
      expect(task.outputs.single.isImage, isTrue);
      expect(model.taskStats?.lastRunTime, isNull);
    });

    test('accepts a response without task references', () {
      final task = WiroTask.fromJson(const {});

      expect(task.id, isNull);
      expect(task.taskToken, isNull);
    });

    test('parses structured language-model output', () {
      final output = WiroTaskOutput.fromJson({
        'contenttype': 'raw',
        'content': {
          'prompt': 'Hello',
          'raw': 'Raw response',
          'thinking': ['Think'],
          'answer': ['Answer'],
        },
      });

      expect(output.content?.prompt, 'Hello');
      expect(output.content?.rawText, 'Raw response');
      expect(output.content?.thinking, ['Think']);
      expect(output.content?.answers, ['Answer']);
    });

    test('preserves an unknown status', () {
      final task = WiroTask.fromJson({
        'id': '1',
        'socketaccesstoken': 'task-token',
        'status': 'task_new_status',
      });

      expect(task.status, WiroTaskStatus.unknown);
      expect(task.statusValue, 'task_new_status');
    });

    test('ignores malformed nested JSON without throwing', () {
      final task = WiroTask.fromJson({
        'id': '1',
        'socketaccesstoken': 'task-token',
        'parameters': '{invalid',
      });

      expect(task.parameters, isEmpty);
    });
  });

  group('WiroTaskUpdate', () {
    test('creates snapshot, event, and binary variants', () {
      final task = WiroTask.fromJson({
        'id': '1',
        'socketaccesstoken': 'task-token',
        'status': 'task_start',
      });
      final event = WiroSocketMessageEvent.fromJson({
        'id': '1',
        'tasktoken': 'task-token',
        'type': 'task_output',
        'message': 'Generating',
      });

      final snapshot = WiroTaskUpdate.fromTask(task);
      final socket = WiroTaskUpdate.fromSocketEvent(event);
      final binaryEvent = WiroSocketBinaryEvent(const [1, 2, 3]);
      final binary = WiroTaskUpdate.fromSocketEvent(binaryEvent);

      expect(snapshot, isA<WiroTaskSnapshotUpdate>());
      expect(socket, isA<WiroTaskEventUpdate>());
      expect(event.id?.value, '1');
      expect(binary, isA<WiroTaskBinaryUpdate>());
      expect((binary as WiroTaskBinaryUpdate).bytes, [1, 2, 3]);
      expect(identical(binary.bytes, binaryEvent.bytes), isTrue);
    });
  });

  group('WiroSocketPayload', () {
    test('decodes log, progress, outputs, and unknown payloads', () {
      WiroSocketMessageEvent event(Object? message, {String? type}) {
        return WiroSocketMessageEvent.fromJson({
          'id': '1',
          'tasktoken': 'task-token',
          'type': type ?? 'task_output',
          'message': message,
        });
      }

      final log = event('Generating');
      final progress = event(const {
        'type': 'progressGenerate',
        'percentage': '50',
      });
      final outputs = event(const [
        {'contenttype': 'audio/mpeg', 'size': '20'},
      ], type: 'task_postprocess_end');
      final unknown = event(const {'future': true});

      expect(log.payload, isA<WiroLogPayload>());
      expect(log.messageText, 'Generating');
      expect(progress.payload, isA<WiroProgressPayload>());
      expect(progress.progress?.percentage, 50);
      expect(outputs.payload, isA<WiroOutputsPayload>());
      expect(outputs.outputs.single.isAudio, isTrue);
      expect(unknown.payload, isA<WiroUnknownPayload>());
    });

    test('decodes JSON-string progress and preserves plain logs', () {
      final progress = WiroSocketMessageEvent.fromJson(const {
        'type': 'task_output',
        'message': '{"type":"progressGenerate","percentage":"75"}',
      });
      final log = WiroSocketMessageEvent.fromJson(const {
        'type': 'task_output',
        'message': 'Generating',
      });

      expect(progress.taskToken, isNull);
      expect(progress.id, isNull);
      expect(progress.payload, isA<WiroProgressPayload>());
      expect(progress.progress?.percentage, 75);
      expect(log.payload, isA<WiroLogPayload>());
      expect(log.messageText, 'Generating');
    });
  });

  group('WiroUploadResult', () {
    test('parses uploaded files', () {
      final result = WiroUploadResult.fromJson({
        'result': true,
        'errors': <Object?>[],
        'list': [
          {
            'id': 'file-1',
            'name': 'photo.png',
            'contenttype': 'image/png',
            'size': '2048',
            'url': 'https://cdn.wiro.ai/photo.png',
          },
        ],
      });

      expect(result.isSuccess, isTrue);
      expect(result.files.single.name, 'photo.png');
      expect(result.files.single.size, 2048);
    });
  });

  group('WiroExploreCategory', () {
    test('parses curated model groups', () {
      final category = WiroExploreCategory.fromJson({
        'id': 'image',
        'title': 'Image',
        'url': 'https://wiro.ai/models/image',
        'tools': [
          {
            'id': '1',
            'cleanslugowner': 'black-forest-labs',
            'cleanslugproject': 'flux-2-pro',
          },
        ],
      });

      expect(category.id, 'image');
      expect(category.total, 1);
      expect(
        category.models.single.modelId?.value,
        'black-forest-labs/flux-2-pro',
      );
      expect(category.url?.host, 'wiro.ai');
    });
  });

  group('WiroApiError', () {
    test('parses response errors and fallbacks', () {
      final result = WiroPaginatedResult<WiroModel>.fromJson(
        {
          'result': false,
          'errors': [
            {'code': 42, 'message': 'Invalid input'},
            <String, Object?>{},
          ],
          'tool': <Object?>[],
        },
        itemsKey: 'tool',
        itemFromJson: WiroModel.fromJson,
      );
      final fallback = WiroApiError.fromJson(const {});

      expect(result.errors.single.code, '42');
      expect(result.errors.single.message, 'Invalid input');
      expect(fallback.message, 'Unknown Wiro API error');
    });
  });
}
