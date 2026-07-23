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
      'openai/sora-2',
      parameters: {
        'prompt': 'A cinematic drone shot over snowy mountains',
        'seconds': '4',
        'resolution': '720p',
        'ratio': '16:9',
      },
      onTaskUpdate: (task) {
        stdout.writeln('Status: ${task.statusValue}');
      },
    );

    for (final output in task.outputs) {
      stdout.writeln(output.url);
    }
  } finally {
    client.close();
  }
}
