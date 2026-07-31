/// Internal maintainer tool that generates a typed request class for a
/// Wiro model. Not shipped as a runnable command to SDK consumers.
///
/// ```bash
/// # Fetch the live schema and generate into lib/src/request/:
/// dart run tool/generate.dart openai/gpt-image-2 --api-key YOUR_KEY
///
/// # Or use the WIRO_API_KEY environment variable:
/// WIRO_API_KEY=YOUR_KEY dart run tool/generate.dart openai/gpt-image-2
///
/// # Or generate offline from a saved model-detail JSON payload:
/// dart run tool/generate.dart --from-json schema.json
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:wiro_client/src/codegen/request_generator.dart';
import 'package:wiro_client/wiro_client.dart';

const _usage = '''
Generates a typed WiroModelRequest class for a Wiro model.

Usage:
  dart run tool/generate.dart <owner/model> [options]

Options:
  --api-key <key>     Wiro API key (defaults to WIRO_API_KEY env var)
  --from-json <file>  Read a saved model-detail JSON payload instead of
                      calling the Wiro API
  -o, --output <dir>  Output directory (defaults to lib/src/request)
  -h, --help          Show this help
''';

Future<void> main(List<String> arguments) async {
  String? modelArg;
  String? apiKey;
  String? fromJson;
  var output = 'lib/src/request';

  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    switch (argument) {
      case '-h' || '--help':
        stdout.write(_usage);
        return;
      case '--api-key':
        apiKey = arguments[++i];
      case '--from-json':
        fromJson = arguments[++i];
      case '-o' || '--output':
        output = arguments[++i];
      default:
        if (argument.startsWith('-')) {
          stderr.writeln('Unknown option: $argument\n\n$_usage');
          exitCode = 64;
          return;
        }
        modelArg = argument;
    }
  }

  if (modelArg == null && fromJson == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  final WiroModelSchema schema;
  if (fromJson != null) {
    final payload = jsonDecode(File(fromJson).readAsStringSync());
    schema = WiroModelSchema.fromJson((payload as Map).cast<String, Object?>());
  } else {
    apiKey ??= Platform.environment['WIRO_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      stderr.writeln(
        'A Wiro API key is required to fetch the model schema. Pass '
        '--api-key or set the WIRO_API_KEY environment variable.',
      );
      exitCode = 64;
      return;
    }
    final client = WiroClient(apiKey: apiKey);
    try {
      schema = await client.getModelSchema(WiroModelId.parse(modelArg!));
    } finally {
      client.close();
    }
  }

  final modelId = modelArg != null
      ? WiroModelId.parse(modelArg)
      : schema.model.modelId;
  if (modelId == null) {
    stderr.writeln(
      'The schema payload does not identify a model. Pass the '
      '<owner/model> argument explicitly.',
    );
    exitCode = 64;
    return;
  }

  final source = generateRequestSource(schema: schema, modelId: modelId);
  final fileName =
      'wiro_${modelId.project.replaceAll(RegExp('[^a-z0-9]+'), '_')}'
      '_request.dart';
  final file = File('$output/$fileName')
    ..createSync(recursive: true)
    ..writeAsStringSync(source);

  // Best effort; the generated source is valid without formatting.
  Process.runSync('dart', ['format', file.path]);

  final className = RegExp(
    r'final class (\w+) implements',
  ).firstMatch(source)![1];
  stdout
    ..writeln('Generated ${file.path}')
    ..writeln('''

Use it with any WiroClient:

  final result = await client.subscribeRequest(
    $className(...),
  );
''');
}
