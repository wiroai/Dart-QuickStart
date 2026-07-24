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
      'runway/gen-4-5',
      parameters: {
        'prompt': 'A cinematic drone shot over snowy mountains',
        'ratio': '16:9',
        'duration': 2,
      },
      trackingMode: WiroTaskTrackingMode.webSocket,
      onUpdate: (update) {
        final percentage = update.progress?.percentage;
        stdout.writeln(
          'Status: ${update.statusValue}'
          '${percentage == null ? '' : ' ($percentage%)'}',
        );
      },
    );
    for (final output in task.outputs) {
      stdout.writeln(output.url);
    }
  } finally {
    client.close();
  }
}
