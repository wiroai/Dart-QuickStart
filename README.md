<div align="center">

# Wiro AI SDK for Dart and Flutter

The official type-safe Dart client for discovering and running AI models on
[Wiro](https://wiro.ai).

[![CI](https://github.com/wiroai/wiro-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/wiroai/wiro-dart/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/wiroai/wiro-dart/branch/main/graph/badge.svg)](https://codecov.io/gh/wiroai/wiro-dart)
[![pub package](https://img.shields.io/pub/v/wiro_ai.svg)](https://pub.dev/packages/wiro_ai)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

## Features

- Search and explore available AI models
- Read typed model input schemas
- Run image, video, audio, and other generative models
- Upload files
- Poll tasks or observe progress with `Stream<WiroTask>`
- Cancel queued tasks and stop running tasks
- Typed errors for authentication, validation, rate limits, and networking
- Request cancellation, timeouts, retry with exponential backoff, and logging
- API key and signature-based authentication
- Pure Dart core with Flutter, image, and video examples

## Requirements

- Dart `3.8.0` or newer
- A [Wiro project and API key](https://wiro.ai/panel/project/new)

## Installation

```bash
dart pub add wiro_ai
```

For Flutter applications:

```bash
flutter pub add wiro_ai
```

## Quick start

```dart
import 'package:wiro_ai/wiro_ai.dart';

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
final run = await client.runModel(
  'openai/sora-2',
  parameters: {
    'prompt': 'A cinematic drone shot over snowy mountains',
    'seconds': '4',
    'resolution': '720p',
    'ratio': '16:9',
  },
);

final task = await client.waitForTask(run.taskToken);
if (task.isSuccessful) {
  for (final output in task.outputs) {
    print(output.url);
  }
}
```

Get the accepted parameters before running a model:

```dart
final schema = await client.getModelSchema('openai/sora-2');
for (final parameter in schema.parameters) {
  print('${parameter.id}: ${parameter.type}');
}
```

## Observe task progress

```dart
await for (final task in client.watchTask(run.taskToken)) {
  print(task.statusValue);
}
```

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

Logs never contain API keys, secrets, headers, or request bodies.

## Error handling

```dart
try {
  await client.explore();
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
} on WiroUnknownApiException catch (error) {
  print('${error.statusCode}: ${error.message}');
}
```

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
- [API reference](https://pub.dev/documentation/wiro_ai/latest/)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

MIT
