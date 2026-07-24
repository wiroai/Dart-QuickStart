<div align="center">

# Wiro AI SDK for Dart and Flutter

The official type-safe Dart client for discovering and running AI models on
[Wiro](https://wiro.ai).

[![CI](https://github.com/wiroai/wiro-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/wiroai/wiro-dart/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/wiroai/wiro-dart/branch/main/graph/badge.svg)](https://codecov.io/gh/wiroai/wiro-dart)
[![pub package](https://img.shields.io/pub/v/wiro_client.svg)](https://pub.dev/packages/wiro_client)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

## Features

- Search and explore available AI models
- Read typed model input schemas
- Run image, video, audio, and other generative models
- Submit and await a task with one `subscribe` call
- Upload byte arrays or streams
- Poll tasks or stream typed progress over WebSocket
- Cancel queued tasks and stop running tasks
- Typed errors for authentication, validation, rate limits, and networking
- Request cancellation, timeouts, retry with exponential backoff, and logging
- API key and signature-based authentication
- Pure Dart core with Flutter, image, and video examples

## Requirements

- Dart `3.8.0` or newer
- Flutter `3.32.8` or newer when used in a Flutter application
- A [Wiro project and API key](https://wiro.ai/panel/project/new)

The core package is pure Dart and supports Dart VM, Android, iOS, web,
macOS, Windows, and Linux. Version `0.x` may receive API refinements before
the first stable release.

## Installation

```bash
dart pub add wiro_client
```

For Flutter applications:

```bash
flutter pub add wiro_client
```

## Quick start

```dart
import 'package:wiro_client/wiro_client.dart';

Future<void> main() async {
  final client = WiroClient(apiKey: 'your-api-key');

  try {
    final result = await client.searchModels(search: 'video');
    for (final model in result.items) {
      print(model.identifier);
    }
  } finally {
    client.close();
  }
}
```

## Run a model

Model parameters remain dynamic because every model has a different schema.
Responses are fully typed.

```dart
final task = await client.subscribe(
  'black-forest-labs/flux-2-pro',
  parameters: {
    'prompt': 'A cinematic mountain lake at sunrise',
    'width': 1024,
    'height': 1024,
  },
  trackingMode: WiroTaskTrackingMode.webSocket,
  onUpdate: (update) {
    print('${update.statusValue}: ${update.progress?.percentage}');
  },
);

for (final output in task.outputs) {
  print(output.url);
}
```

`subscribe` throws `WiroTaskFailedException` when the terminal task did not
succeed. `trackingMode` can be `polling` or `webSocket`; polling is the
backward-compatible default. Both modes emit `WiroTaskUpdate`.

Use the lower-level API when submission and tracking must be managed separately:

```dart
final run = await client.runModel(
  'openai/sora-2',
  parameters: {'prompt': 'A cinematic mountain lake'},
  callbackUrl: Uri.parse('https://example.com/wiro-webhook'),
);
final task = await client.waitForTask(run.taskToken);
```

Get the accepted parameters before running a model:

```dart
final schema = await client.getModelSchema('openai/sora-2');
for (final parameter in schema.parameters) {
  print('${parameter.id}: ${parameter.type}');
}
```

## File inputs and uploads

Model parameters accept remote URLs. `fileinput` values can use the parameter
itself or its `Url` companion. `combinefileinput` values accept a list of URLs:

```dart
final run = await client.runModel(
  'openai/sora-2',
  parameters: {
    'prompt': 'Animate this image',
    'inputImage': ['https://example.com/input.jpg'],
    'seconds': '4',
  },
);
```

Upload local bytes first when a public URL is not available:

```dart
final upload = await client.uploadFile(
  bytes,
  fileName: 'input.jpg',
);
final url = upload.files.single.url;
```

Use `uploadStream` with an exact `contentLength` for large files. Streaming
avoids SDK-side buffering on supported runtimes.

## Observe task progress

Use WebSocket for realtime lifecycle, progress, LLM, and binary events:

```dart
await for (final event in client.watchTaskSocket(run.taskToken)) {
  switch (event) {
    case WiroSocketMessageEvent(
      :final statusValue,
      :final progress,
      :final outputs,
    ):
      print('$statusValue: ${progress?.percentage}');
      for (final output in outputs) {
        print(output.url);
      }
    case WiroSocketBinaryEvent(:final bytes):
      print('Received ${bytes.length} realtime bytes');
  }
}
```

The socket uses Wiro's `task_info` protocol and closes after
`task_postprocess_end` or `task_cancel`. Binary frames are preserved for
realtime audio models.

Polling remains available as a fallback:

```dart
await for (final task in client.watchTask(
  run.taskToken,
  timeout: const Duration(minutes: 10),
)) {
  print(task.statusValue);
}
```

For a definitive success check, fetch the terminal task and verify
`task.isSuccessful`.

## Cancellation

```dart
final cancellationToken = WiroCancellationToken();

final request = client.searchModels(
  search: 'image',
  cancellationToken: cancellationToken,
);

cancellationToken.cancel();
await request;
```

Cancelled requests throw `WiroRequestCancelledException`.

## Retries, timeouts, and logging

```dart
final client = WiroClient(
  apiKey: 'your-api-key',
  requestTimeout: const Duration(seconds: 20),
  pollInterval: const Duration(seconds: 2),
  retryPolicy: const WiroRetryPolicy(
    maxRetries: 3,
    initialDelay: Duration(milliseconds: 500),
  ),
  logger: (event) {
    print('${event.level.name}: ${event.message}');
  },
);
```

Automatic retries apply only to safe read-like operations such as model and
task lookup. Model runs and file uploads are not retried because they can
create duplicate billable work. Rate-limit retries respect `Retry-After`.

Logs never contain API keys, secrets, headers, or request bodies.

## Error handling

```dart
try {
  await client.explore();
} on WiroApiResultException catch (error) {
  // HTTP succeeded, but Wiro rejected the operation.
  print('${error.code}: ${error.message}');
} on WiroAuthenticationException {
  // Invalid or expired credentials.
} on WiroRateLimitException catch (error) {
  print('Retry after: ${error.retryAfter}');
} on WiroValidationException catch (error) {
  print(error.message);
} on WiroTimeoutException {
  // Request or task polling timed out.
} on WiroNetworkException {
  // The API could not be reached.
} on WiroTaskFailedException catch (error) {
  print(error.task.debugOutput);
} on WiroUnknownApiException catch (error) {
  print('${error.statusCode}: ${error.message}');
}
```

Wiro can report application-level failures with HTTP 2xx and `result: false`.
The SDK converts these responses to `WiroApiResultException`.

## Authentication

API key authentication:

```dart
final client = WiroClient(apiKey: 'your-api-key');
```

Signature-based authentication:

```dart
final client = WiroClient(
  apiKey: 'your-api-key',
  apiSecret: 'your-api-secret',
);
```

The configured credentials must match the authentication type selected for
the Wiro project.

Never embed long-lived Wiro credentials in a production mobile application.
Call Wiro through your backend or use a short-lived client token flow when
one is available.

## Examples

The `example` directory contains:

- A Flutter iOS and Android model explorer
- `bin/generate_image.dart` using Flux 2 Pro
- `bin/generate_video.dart` using Sora 2 with streamed task progress

```bash
cd example

WIRO_API_KEY=your-api-key dart run bin/generate_image.dart
WIRO_API_KEY=your-api-key dart run bin/generate_video.dart

flutter run --dart-define=WIRO_API_KEY=your-api-key
```

The `dart-define` approach is only for local demonstration. Build-time values
can be extracted from a distributed mobile application.

## Documentation

- [Wiro documentation](https://wiro.ai/docs)
- [Available models](https://wiro.ai/models)
- [API reference](https://pub.dev/documentation/wiro_client/latest/)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

MIT
