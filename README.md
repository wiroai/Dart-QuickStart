<div align="center">

<img src="https://raw.githubusercontent.com/wiroai/Dart-QuickStart/main/.github/assets/wiro-logo.png" alt="Wiro AI" width="240">

# Wiro AI SDK for Dart and Flutter

Run image, video, audio and LLM models from Dart and Flutter apps with the Wiro AI API: typed requests, live task tracking and file uploads.

[![pub package](https://img.shields.io/pub/v/wiro?style=for-the-badge&color=111111&logo=dart&logoColor=white&label=pub)](https://pub.dev/packages/wiro) [![Dart 3.8+](https://img.shields.io/badge/Dart-3.8%2B-111111?style=for-the-badge&color=111111&logo=dart&logoColor=white)](https://dart.dev) [![Flutter 3.32.8+](https://img.shields.io/badge/Flutter-3.32.8%2B-111111?style=for-the-badge&color=111111&logo=flutter&logoColor=white)](https://flutter.dev) [![CI](https://img.shields.io/github/actions/workflow/status/wiroai/Dart-QuickStart/ci.yml?branch=main&style=for-the-badge&color=111111&label=CI&logo=githubactions&logoColor=white)](https://github.com/wiroai/Dart-QuickStart/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/license-MIT-111111?style=for-the-badge&color=111111)](LICENSE)

[Website](https://wiro.ai) · [Models](https://wiro.ai/models) · [Docs](https://wiro.ai/docs/code-examples) · [Dashboard](https://wiro.ai/panel) · [pub.dev](https://pub.dev/packages/wiro)

</div>

`wiro` is the official Dart package for calling the
[Wiro AI](https://wiro.ai) model API from Flutter apps, Dart servers and
command-line tools. It runs any model in the Wiro AI catalog, through typed
request classes for popular image, video and music models or through
`Wiro.model` with a parameter map, and follows each task by polling or over a
WebSocket. The `example` folder has a Flutter text-to-image app and four
command-line scripts.

## Features

- Search and explore available AI models
- Run popular models with compile-time checked typed requests
- Read typed model input schemas
- Validate dynamic parameters against model schemas
- Run image, video, audio, and other generative models
- Use typed model IDs, task tokens, and task IDs
- Submit and await a sealed task result with one `subscribe` call
- Send device files as model inputs with automatic uploads
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
- A [Wiro AI project and API key](https://wiro.ai/panel/project/new)

The core package is pure Dart and supports Dart VM, Android, iOS, web,
macOS, Windows, and Linux. Version `0.x` may receive API refinements before
the first stable release.

## Installation

```bash
dart pub add wiro
```

For Flutter applications:

```bash
flutter pub add wiro
```

## Quick start

Any model on Wiro AI runs through `Wiro.model`. Type `Wiro.` in your IDE
to discover typed factories for popular models as well:

<p align="center">
  <img
    src="doc/images/carbon-any-model.png"
    alt="Run any Wiro AI model with Wiro.model"
    width="720"
  />
</p>

```dart
import 'package:wiro/wiro.dart';

Future<void> main() async {
  final client = WiroClient(apiKey: 'your-api-key');

  try {
    final result = await client.subscribeRequest(
      Wiro.model(
        'black-forest-labs/flux-2-pro',
        parameters: {
          'prompt': 'A cinematic mountain lake',
          'width': 1024,
          'height': 1024,
        },
      ),
    );
    print(result.task.outputs.first.url);
  } finally {
    client.close();
  }
}
```

## Which call do I need?

| I want to... | Call |
| --- | --- |
| Generate with a supported model | `client.subscribeRequest(Wiro.flux2Pro(...))` |
| Run any other model | `client.subscribeRequest(Wiro.model('owner/model', parameters: {...}))` |
| Find a model | `client.searchModels(search: '...')` or `client.explore()` |
| See what parameters a model takes | `client.getModelSchema(...)`, then `schema.validate(params)` |
| Watch progress | `onUpdate:` callback, or `client.subscribeStream(...)` |
| Send a device file to a model | `WiroFileInput.bytes(bytes, fileName: '...')`, uploaded automatically |
| Cancel or stop a task | `client.cancelTask(...)` / `client.killTask(...)` |
| Keep API keys off the device | `WiroClient.proxied(proxyUri: ...)` |
| Handle failure | `switch` on `WiroTaskSuccess` / `WiroTaskFailure(:reason)` |

## Run a model with a typed request

Popular models ship with typed request classes, so required parameters and
select options are checked at compile time and value ranges are checked by
assertions in debug builds:

<p align="center">
  <img
    src="doc/images/carbon-typed-request.png"
    alt="Compile-time checked typed request with Wiro.flux2Pro"
    width="720"
  />
</p>

```dart
final result = await client.subscribeRequest(
  Wiro.flux2Pro(
    prompt: 'A cinematic mountain lake at sunrise',
    width: 1024,
    height: 1024,
    outputFormat: WiroFlux2ProOutputFormat.png,
  ),
);

switch (result) {
  case WiroTaskSuccess(:final task):
    print(task.outputs.first.url);
  case WiroTaskFailure(:final reason):
    print('Failed: ${reason.name}');
}
```

Type `Wiro.` in your IDE to list every model with a typed request;
each factory (such as `Wiro.flux2Pro`) returns the matching request
class. Typed requests generated from the live Wiro AI schemas are included for:

| Category | Models |
| --- | --- |
| Image | FLUX.2 Pro, GPT Image 2, Nano Banana Pro, Seedream v4, Grok Imagine Image |
| Video | Runway Gen-4.5, Seedance 2.0, Kling V3, Veo 3.1, Sora 2 Pro, Hailuo 2.3 Fast, Grok Imagine Video |
| Music | Lyria 3 |

Any other model runs through `Wiro.model` as shown below. `runRequest`
is the non-tracking equivalent of `subscribeRequest`.

Typed requests are generated from the live Wiro AI model schemas with an
internal tool, so coverage grows with SDK releases. Missing a model?
[Open an issue](https://github.com/wiroai/Dart-QuickStart/issues) to request a
typed binding, or implement `WiroModelRequest` yourself in the meantime.

## Run any model with `Wiro.model`

Models without a typed factory run through `Wiro.model` with a dynamic
parameter map, so every model works even before the SDK ships a binding
for it. Responses are fully typed.

```dart
final result = await client.subscribeRequest(
  Wiro.model(
    'black-forest-labs/flux-2-pro',
    parameters: {
      'prompt': 'A cinematic mountain lake at sunrise',
      'width': 1024,
      'height': 1024,
    },
  ),
  trackingMode: WiroTaskTrackingMode.webSocket,
  onUpdate: (update) {
    switch (update) {
      case WiroTaskEventUpdate(
        event: WiroSocketMessageEvent(
          payload: WiroProgressPayload(:final progress),
        ),
      ):
        print('${update.statusValue}: ${progress.percentage}');
      case _:
        print(update.statusValue);
    }
  },
);

for (final output in result.task.outputs) {
  print(output.url);
}
```

`subscribe` returns `WiroTaskSuccess` or `WiroTaskFailure`, both carrying the
terminal task. `trackingMode` can be `polling` or `webSocket`; polling is the
default. Both modes emit sealed `WiroTaskUpdate` variants. Failures expose a
typed `reason`, and `result.task.elapsed` reports fractional task duration as
a `Duration`.

Use the lower-level API when submission and tracking must be managed separately:

```dart
final run = await client.runModel(
  WiroModelId('openai', 'sora-2'),
  parameters: {'prompt': 'A cinematic mountain lake'},
  callbackUrl: Uri.parse('https://example.com/wiro-webhook'),
);
final taskToken = run.taskToken;
if (taskToken == null) {
  throw StateError('Wiro did not return a task token.');
}
final task = await client.waitForTask(taskToken);
```

Server-derived model IDs, task IDs, task tokens, and socket event IDs are
nullable when the Wiro AI API omits or returns invalid identifier fields. Identifiers
created explicitly with `WiroModelId`, `WiroTaskId`, or `WiroTaskToken` remain
strictly validated.

Get the accepted parameters before running a model:

```dart
final schema = await client.getModelSchema(
  WiroModelId('openai', 'sora-2'),
);
for (final parameter in schema.parameters) {
  print('${parameter.id}: ${parameter.runtimeType}');
}
schema.validate({'prompt': 'A cinematic mountain lake'});
```

Select, number, and text parameter variants expose typed `defaultValue`
fields. Unknown variants preserve dynamic defaults, while file parameter
defaults remain available through `parameter.raw['default']`.

## File inputs and uploads

File parameters take `WiroFileInput` values. Wrap an already-hosted file
with `WiroFileInput.url`, or pass raw device bytes (a gallery pick, a
camera shot) with `WiroFileInput.bytes`. The client uploads the bytes
automatically and swaps in the URL before the model runs:

```dart
final result = await client.subscribeRequest(
  Wiro.model(
    'google/upscaler',
    parameters: {
      'inputImage': [
        WiroFileInput.bytes(
          await image.readAsBytes(),
          fileName: 'photo.jpg',
        ),
      ],
      'upscaleFactor': 4,
    },
  ),
);

print(result.task.outputs.first.url);
```

The same works inside dynamic parameter maps:

```dart
final run = await client.runModel(
  WiroModelId('openai', 'sora-2'),
  parameters: {
    'prompt': 'Animate this image',
    'inputImage': [
      WiroFileInput.url(Uri.parse('https://example.com/input.jpg')),
    ],
    'seconds': '4',
  },
);
```

To manage uploads yourself, call `client.uploadFile(bytes, fileName: ...)`
and pass the returned URL, or use `uploadStream` with an exact
`contentLength` for large files. Streaming avoids SDK-side buffering on
supported runtimes.

## Observe task progress

Pass `onUpdate` or use WebSocket tracking to watch a run live:

```dart
final result = await client.subscribeRequest(
  Wiro.runwayGen45(
    prompt: 'A drone shot over misty mountains',
    ratio: WiroRunwayGen45Ratio.landscape16x9,
    duration: 2,
  ),
  trackingMode: WiroTaskTrackingMode.webSocket,
  onUpdate: (update) {
    print(update.statusValue);
  },
);
```

Use `subscribeStream` when an `await for` loop is more convenient than a
callback:

```dart
await for (final update in client.subscribeStream(
  WiroModelId('black-forest-labs', 'flux-2-pro'),
  parameters: {'prompt': 'A cinematic mountain lake'},
)) {
  print(update.statusValue);
}
```

Use WebSocket for realtime lifecycle, progress, LLM, and binary events:

```dart
await for (final event in client.watchTaskSocket(taskToken)) {
  switch (event) {
    case WiroSocketMessageEvent(
      :final statusValue,
      :final payload,
    ):
      switch (payload) {
        case WiroLogPayload(:final message):
          print('$statusValue: $message');
        case WiroProgressPayload(:final progress):
          print('$statusValue: ${progress.percentage}');
        case WiroOutputsPayload(:final outputs):
          for (final output in outputs) {
            print(output.url);
          }
        case WiroUnknownPayload():
          print('$statusValue: unknown payload');
      }
    case WiroSocketBinaryEvent(:final bytes):
      print('Received ${bytes.length} realtime bytes');
  }
}
```

The socket uses the Wiro AI `task_info` protocol and closes after
`task_postprocess_end` or `task_cancel`. Binary frames are preserved for
realtime audio models.

Polling remains available as a fallback:

```dart
await for (final task in client.watchTask(
  taskToken,
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
Cancelling a `subscribeStream` subscription also stops its active polling or
WebSocket tracking without emitting a cancellation error.

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
Malformed nested JSON ignored during response parsing is reported as a debug
log event instead of through global diagnostics state.

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
} on WiroSchemaValidationException catch (error) {
  print(error.issues);
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

The Wiro AI API can report application-level failures with HTTP 2xx and
`result: false`.
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
the Wiro AI project.

Never embed long-lived Wiro AI credentials in a production mobile application.
Use a proxied client so credentials stay on your backend:

```dart
final client = WiroClient.proxied(
  proxyUri: Uri.parse('https://your-backend.example.com/wiro'),
  headers: {'Authorization': 'Bearer $sessionToken'},
);
```

The device sends requests to your proxy without any Wiro AI auth headers. The proxy
must accept the same REST paths as the Wiro AI API, attach `x-api-key` (and
signature headers when required), and forward the request to
`https://api.wiro.ai/v1`. Task WebSocket streams still connect directly to
Wiro AI because they authenticate with per-task tokens instead of API
credentials.

## Examples

The `example` directory contains:

- A Flutter iOS and Android text-to-image app built on `Wiro.flux2Pro`
- `bin/generate_image.dart` using Flux 2 Pro
- `bin/generate_video.dart` using Runway Gen-4.5 with streamed task progress
- `bin/generate_dynamic.dart` running a model through `Wiro.model` after
  `schema.validate`
- `bin/upscale_image.dart` sending a file input from a public URL or local
  bytes

```bash
cd example

WIRO_API_KEY=your-api-key dart run bin/generate_image.dart
WIRO_API_KEY=your-api-key dart run bin/generate_video.dart
WIRO_API_KEY=your-api-key dart run bin/generate_dynamic.dart
WIRO_API_KEY=your-api-key dart run bin/upscale_image.dart ./photo.jpg

flutter run --dart-define=WIRO_API_KEY=your-api-key
```

The `dart-define` approach is only for local demonstration. Build-time values
can be extracted from a distributed mobile application.

## Documentation

- Product docs: [https://wiro.ai/docs](https://wiro.ai/docs)
- Available models: [https://wiro.ai/models](https://wiro.ai/models)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- Security policy: [`SECURITY.md`](SECURITY.md)
- Contributing guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)

## More from Wiro AI

| Repository | What it is |
| --- | --- |
| [Wiro-MCP](https://github.com/wiroai/Wiro-MCP) | Official MCP server for Wiro AI, [`@wiro-ai/wiro-mcp` on npm](https://www.npmjs.com/package/@wiro-ai/wiro-mcp) |
| [Wiro-Plugin](https://github.com/wiroai/Wiro-Plugin) | Wiro AI plugin for Cursor, Claude Code, Gemini CLI and Devin |
| [Swift-QuickStart](https://github.com/wiroai/Swift-QuickStart) | WiroKit, the Wiro AI SDK for iOS |
| [Kotlin-QuickStart](https://github.com/wiroai/Kotlin-QuickStart) | WiroKit, the Wiro AI SDK for Android |
| [ReactNative-QuickStart](https://github.com/wiroai/ReactNative-QuickStart) | Wiro AI SDK for React Native and Expo, [`@wiro-ai/wiro-react-native` on npm](https://www.npmjs.com/package/@wiro-ai/wiro-react-native) |
| [Swift-Realtime](https://github.com/wiroai/Swift-Realtime) | Realtime voice AI example for iOS |
| [Kotlin-Realtime](https://github.com/wiroai/Kotlin-Realtime) | Realtime voice AI example for Android |
| [Dart-Realtime](https://github.com/wiroai/Dart-Realtime) | Realtime voice AI example for Flutter |
| [ReactNative-Realtime](https://github.com/wiroai/ReactNative-Realtime) | Realtime voice AI example for React Native |
| [n8n-nodes-wiroai](https://github.com/wiroai/n8n-nodes-wiroai) | Wiro AI nodes for n8n, [`@wiro-ai/n8n-nodes-wiroai` on npm](https://www.npmjs.com/package/@wiro-ai/n8n-nodes-wiroai) |
| [Wiro-Docs](https://github.com/wiroai/Wiro-Docs) | Source of the Wiro AI API docs |

[Website](https://wiro.ai) · [Models](https://wiro.ai/models) · [Docs](https://wiro.ai/docs) · [X](https://x.com/wiroai)

## License

MIT. See [LICENSE](LICENSE).

<div align="center">

<img src="https://wiro.ai/images/koala/accent-heavy-koala.png" alt="Wiro AI koala mascot" width="80">

</div>
