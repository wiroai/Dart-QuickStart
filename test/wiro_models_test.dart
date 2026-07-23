import 'package:test/test.dart';
import 'package:wiro_ai/wiro_ai.dart';

void main() {
  group('WiroModelSchema', () {
    test('parses model metadata and parameters', () {
      final schema = WiroModelSchema.fromJson({
        'id': '1',
        'title': 'Sora 2',
        'cleanslugowner': 'openai',
        'cleanslugproject': 'sora-2',
        'categories': ['text-to-video'],
        'parameters': [
          {
            'title': 'Inputs',
            'items': [
              {
                'id': 'seconds',
                'type': 'select',
                'label': 'Seconds',
                'required': true,
                'options': [
                  {'label': '4 seconds', 'value': '4'},
                ],
              },
            ],
          },
        ],
      });

      expect(schema.model.identifier, 'openai/sora-2');
      expect(schema.model.categories, ['text-to-video']);
      expect(schema.parameters.single.id, 'seconds');
      expect(schema.parameters.single.isRequired, isTrue);
      expect(schema.parameters.single.options.single.value, '4');
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
          'lastruntime': '2026-07-23',
        },
      });

      expect(model.identifier, 'wiro/demo');
      expect(model.imageUrl?.host, 'cdn.wiro.ai');
      expect(model.taskStats?.successCount, 8);
      expect(model.tags, ['featured']);
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
      expect(result.items.single.identifier, 'wiro/example');
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
      expect(result.taskId, '2221');
      expect(result.taskToken, 'task-token');
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
      expect(task.elapsedSeconds, 3.5);
      expect(task.outputs.single.url?.host, 'cdn.wiro.ai');
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
      final task = WiroTask.fromJson({'id': '1', 'status': 'task_new_status'});

      expect(task.status, WiroTaskStatus.unknown);
      expect(task.statusValue, 'task_new_status');
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
        'id': 'video',
        'title': 'Video',
        'url': 'https://wiro.ai/models/video',
        'tools': [
          {
            'id': '1',
            'cleanslugowner': 'openai',
            'cleanslugproject': 'sora-2',
          },
        ],
      });

      expect(category.id, 'video');
      expect(category.total, 1);
      expect(category.models.single.identifier, 'openai/sora-2');
      expect(category.url?.host, 'wiro.ai');
    });
  });

  group('WiroApiError', () {
    test('parses response errors and fallbacks', () {
      final errors = parseWiroApiErrors([
        {'code': 42, 'message': 'Invalid input'},
        <String, Object?>{},
      ]);
      final fallback = WiroApiError.fromJson(const {});

      expect(errors.single.code, 42);
      expect(errors.single.message, 'Invalid input');
      expect(fallback.message, 'Unknown Wiro API error');
    });
  });
}
