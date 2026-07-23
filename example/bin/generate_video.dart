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
    final run = await client.runModel(
      'runway/gen-4-5',
      parameters: {
        'prompt': 'A cinematic drone shot over snowy mountains',
        'ratio': '16:9',
        'duration': 2,
      },
    );

    await for (final event in client.watchTaskSocket(run.taskToken)) {
      if (event case WiroSocketMessageEvent(
        :final statusValue,
        :final progress,
      )) {
        final percentage = progress?.percentage;
        stdout.writeln(
          'Status: $statusValue'
          '${percentage == null ? '' : ' ($percentage%)'}',
        );
      }
    }

    final task = await client.getTask(taskToken: run.taskToken);
    if (!task.isSuccessful) {
      throw WiroTaskFailedException(task);
    }
    for (final output in task.outputs) {
      stdout.writeln(output.url);
    }
  } finally {
    client.close();
  }
}
