import 'package:test/test.dart';
import 'package:wiro_client/src/codegen/request_generator.dart';
import 'package:wiro_client/wiro_client.dart';

void main() {
  group('generateRequestSource', () {
    late String source;

    setUpAll(() {
      source = generateRequestSource(
        schema: WiroModelSchema.fromJson(_modelDetailPayload),
        modelId: WiroModelId('acme', 'demo-video-2'),
        generatedAt: DateTime.utc(2026, 7, 24),
      );
    });

    test('names the class after the model slug', () {
      expect(
        source,
        contains(
          'final class WiroDemoVideo2Request implements '
          'WiroModelRequest',
        ),
      );
      expect(
        source,
        contains("WiroModelId('acme', 'demo-video-2')"),
      );
    });

    test('maps plain selects to enums with wire values', () {
      expect(source, contains('enum WiroDemoVideo2AspectRatio {'));
      expect(source, contains("auto('auto')"));
      expect(source, contains("v16x9('16:9')"));
      expect(source, contains("v9x16('9:16')"));
      expect(source, contains("blockNone('BLOCK_NONE')"));
    });

    test('maps numeric selects to int fields with a whitelist', () {
      expect(source, contains('final int duration;'));
      expect(
        source,
        contains('duration == 5 || duration == 10 || duration == 15'),
      );
      expect(source, contains(r"'duration': '$duration'"));
    });

    test('maps boolean selects to bool fields with string wire values', () {
      expect(source, contains('final bool? watermark;'));
      expect(
        source,
        contains(r"'watermark': watermark == null ? null : '$watermark'"),
      );
    });

    test('maps number parameters to int fields with bound asserts', () {
      expect(source, contains('final int? seed;'));
      expect(source, contains('seed == null || (seed >= 0 && seed <= 100)'));
    });

    test('maps file parameters to file input lists', () {
      expect(source, contains('final List<WiroFileInput>? inputImage;'));
      expect(
        source,
        contains(
          "'inputImage': inputImage?.map((file) => file.wireValue).toList()",
        ),
      );
    });

    test('requires non-empty prompts and removes null entries', () {
      expect(source, contains("assert(prompt != '', 'prompt cannot be"));
      expect(
        source,
        contains('..removeWhere((key, value) => value == null)'),
      );
    });

    test('documents the schema snapshot and regeneration command', () {
      expect(source, contains('// Schema snapshot: 2026-07-24'));
      expect(
        source,
        contains(
          '// Regenerate: dart run tool/generate.dart '
          'acme/demo-video-2',
        ),
      );
    });
  });
}

const Map<String, Object?> _modelDetailPayload = {
  'cleanslugowner': 'acme',
  'cleanslugproject': 'demo-video-2',
  'title': 'Demo Video 2 by Acme',
  'parameters': [
    {
      'title': 'Inputs',
      'items': [
        {
          'id': 'inputImage',
          'type': 'combinefileinput',
          'label': 'First frame',
          'description': 'Optional. First frame image.',
          'required': false,
        },
        {
          'id': 'prompt',
          'type': 'textarea',
          'label': 'Prompt',
          'description': 'Required. Text description of the desired video.',
          'required': true,
        },
        {
          'id': 'duration',
          'type': 'select',
          'label': 'Duration',
          'required': true,
          'options': [
            {'label': '5', 'value': '5'},
            {'label': '10', 'value': '10'},
            {'label': '15', 'value': '15'},
          ],
        },
        {
          'id': 'aspectRatio',
          'type': 'select',
          'label': 'Aspect Ratio',
          'required': true,
          'options': [
            {'label': 'Auto', 'value': 'auto'},
            {'label': '16:9', 'value': '16:9'},
            {'label': '9:16', 'value': '9:16'},
            {'label': 'Block none', 'value': 'BLOCK_NONE'},
          ],
        },
        {
          'id': 'watermark',
          'type': 'select',
          'label': 'Watermark',
          'required': false,
          'options': [
            {'label': 'false', 'value': 'false'},
            {'label': 'true', 'value': 'true'},
          ],
        },
        {
          'id': 'seed',
          'type': 'number',
          'label': 'Seed',
          'required': false,
          'min': 0,
          'max': 100,
        },
      ],
    },
  ],
};
