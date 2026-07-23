import 'dart:io';

import 'package:wiro_ai/wiro_ai.dart';

Future<void> main() async {
  final apiKey = Platform.environment['WIRO_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set WIRO_API_KEY before running this example.');
    exitCode = 64;
    return;
  }

  final client = WiroClient(apiKey: apiKey);
  try {
    final run = await client.runModel(
      'openai/sora-2',
      parameters: {
        'prompt': 'A cinematic drone shot over snowy mountains',
        'seconds': '4',
        'resolution': '720p',
        'ratio': '16:9',
      },
    );

    await for (final task in client.watchTask(run.taskToken)) {
      stdout.writeln('Status: ${task.statusValue}');
      if (task.isSuccessful) {
        for (final output in task.outputs) {
          stdout.writeln(output.url);
        }
      }
    }
  } finally {
    client.close();
  }
}
