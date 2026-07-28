import 'dart:io';

import 'package:wiro_client/wiro_client.dart';

/// Runs any model through [Wiro.model] with a dynamic parameter map.
///
/// Use this when the SDK has no typed factory for the slug, or when you
/// want to pass parameters as a plain map after [WiroModelSchema.validate].
Future<void> main() async {
  final apiKey = Platform.environment['WIRO_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set WIRO_API_KEY before running this example.');
    exitCode = 64;
    return;
  }

  final client = WiroClient(
    apiKey: apiKey,
    apiSecret: Platform.environment['WIRO_API_SECRET'],
  );
  try {
    const slug = 'black-forest-labs/flux-2-pro';
    final modelId = WiroModelId.parse(slug);
    final schema = await client.getModelSchema(modelId);
    final parameters = <String, Object?>{
      'prompt': 'A cinematic mountain lake at sunrise',
      'width': 1024,
      'height': 1024,
      'outputFormat': 'png',
    };
    schema.validate(parameters);

    final result = await client.subscribeRequest(
      Wiro.model(slug, parameters: parameters),
    );

    if (result case WiroTaskFailure(:final reason, :final task)) {
      stderr.writeln(
        task.debugOutput ?? 'Dynamic run failed: ${reason.name}.',
      );
      exitCode = 1;
      return;
    }
    for (final output in result.task.outputs) {
      stdout.writeln(output.url);
    }
  } finally {
    client.close();
  }
}
