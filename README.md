# Wiro AI SDK for Dart and Flutter

The official Dart client for discovering and running AI models on
[Wiro](https://wiro.ai).

## Features

- Search and explore available AI models
- Read model input schemas
- Run image, video, audio, and other generative models
- Upload files
- Inspect, wait for, cancel, and stop tasks
- API key and signature-based authentication
- Pure Dart core with a Flutter example application

## Installation

Add the package to your project:

```bash
dart pub add wiro_ai
```

## Usage

```dart
import 'package:wiro_ai/wiro_ai.dart';

Future<void> main() async {
  final client = WiroClient(apiKey: 'your-api-key');

  try {
    final models = await client.searchModels(search: 'video');
    print(models);
  } finally {
    client.close();
  }
}
```

Run a model and wait for its result:

```dart
final task = await client.runModel(
  'openai/sora-2',
  parameters: {
    'prompt': 'A cinematic drone shot over snowy mountains',
  },
);

final taskToken = task['tasktoken'] as String;
final result = await client.waitForTask(taskToken);
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

## Flutter example

The `example` directory contains an iOS and Android model explorer.
For local development, run it with:

```bash
cd example
flutter run --dart-define=WIRO_API_KEY=your-api-key
```

The `dart-define` approach is only for local demonstration. Build-time values
can be extracted from a distributed mobile application.

## Documentation

- [Wiro documentation](https://wiro.ai/docs)
- [Available models](https://wiro.ai/models)
- [Create a project](https://wiro.ai/panel/project/new)

## License

MIT
