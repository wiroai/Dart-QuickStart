import 'dart:io';

import 'package:wiro_client/wiro_client.dart';

Future<void> main() async {
  final apiKey = Platform.environment['WIRO_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set WIRO_API_KEY before running this example.');
    exitCode = 64;
    return;
  }

  final client = WiroClient(apiKey: apiKey);
  try {
    final task = await client.subscribe(
      'black-forest-labs/flux-2-pro',
      parameters: {
        'prompt': 'A cinematic mountain lake at sunrise',
        'width': 1024,
        'height': 1024,
        'outputFormat': 'png',
      },
    );

    for (final output in task.outputs) {
      stdout.writeln(output.url);
    }
  } finally {
    client.close();
  }
}
