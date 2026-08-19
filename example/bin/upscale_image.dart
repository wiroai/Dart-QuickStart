import 'dart:io';

import 'package:wiro_client/wiro_client.dart';

/// Upscales an image with [WiroFileInput] via `Wiro.model`.
///
/// Pass a local path to demonstrate automatic byte upload:
///
/// ```bash
/// WIRO_API_KEY=... dart run bin/upscale_image.dart ./photo.jpg
/// ```
///
/// Without a path, uses [WiroFileInput.url] with a public sample image.
Future<void> main(List<String> args) async {
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
    final inputImage = await _resolveInput(args);
    stdout.writeln(
      inputImage is WiroBytesInput
          ? 'Using WiroFileInput.bytes (${inputImage.bytes.length} bytes).'
          : 'Using WiroFileInput.url.',
    );

    final result = await client.subscribeRequest(
      Wiro.model(
        'google/upscaler',
        parameters: {
          'inputImage': [inputImage],
          'upscaleFactor': 2,
        },
      ),
    );

    if (result case WiroTaskFailure(:final reason, :final task)) {
      stderr.writeln(
        task.debugOutput ?? 'Upscale failed: ${reason.name}.',
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

Future<WiroFileInput> _resolveInput(List<String> args) async {
  if (args.isEmpty) {
    return WiroFileInput.url(
      Uri.parse(
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=512',
      ),
    );
  }

  final path = args.first;
  final file = File(path);
  if (!file.existsSync()) {
    throw ArgumentError.value(path, 'path', 'File does not exist');
  }
  final bytes = await file.readAsBytes();
  return WiroFileInput.bytes(
    bytes,
    fileName: file.uri.pathSegments.last,
  );
}
