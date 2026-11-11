import 'dart:io';

import 'package:wiro/wiro.dart';

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
    // Typed factory discovered via IDE autocomplete: Wiro.flux2Pro(...)
    final result = await client.subscribeRequest(
      Wiro.flux2Pro(
        prompt: 'A cinematic mountain lake at sunrise',
        width: 1024,
        height: 1024,
        outputFormat: WiroFlux2ProOutputFormat.png,
      ),
    );

    if (result case WiroTaskFailure(:final reason, :final task)) {
      stderr.writeln(
        task.debugOutput ?? 'Image generation failed: ${reason.name}.',
      );
      exitCode = 1;
      return;
    }
    for (final output in result.task.outputs) {
      stdout.writeln(output.url);
    }
    stdout.writeln('Elapsed: ${result.task.elapsed}');
  } finally {
    client.close();
  }
}
