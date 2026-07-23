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
}
