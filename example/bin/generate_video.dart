import 'dart:io';

import 'package:wiro_client/wiro_client.dart';

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
    final result = await client.subscribeRequest(
      Wiro.runwayGen45(
        prompt: 'A cinematic drone shot over snowy mountains',
        ratio: WiroRunwayGen45Ratio.landscape16x9,
        duration: 2,
      ),
      trackingMode: WiroTaskTrackingMode.webSocket,
      onUpdate: (update) {
        final percentage = switch (update) {
          WiroTaskEventUpdate(
            event: WiroSocketMessageEvent(
              payload: WiroProgressPayload(:final progress),
            ),
          ) =>
            progress.percentage,
          _ => null,
        };
        stdout.writeln(
          'Status: ${update.statusValue}'
          '${percentage == null ? '' : ' ($percentage%)'}',
        );
      },
    );
    if (result case WiroTaskFailure(:final reason, :final task)) {
      stderr.writeln(
        task.debugOutput ?? 'Video generation failed: ${reason.name}.',
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
