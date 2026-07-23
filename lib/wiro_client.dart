/// Official Wiro AI SDK for Dart and Flutter.
///
/// Import this library to discover models, inspect their schemas, run model
/// tasks, upload inputs, and observe task progress:
///
/// ```dart
/// final client = WiroClient(apiKey: 'your-api-key');
/// try {
///   final task = await client.subscribe(
///     'black-forest-labs/flux-2-pro',
///     parameters: {'prompt': 'A cinematic mountain lake'},
///   );
///   print(task.outputs.first.url);
/// } finally {
///   client.close();
/// }
/// ```
library;

export 'src/model/wiro_json.dart';
export 'src/model/wiro_model.dart';
export 'src/model/wiro_result.dart' hide parseWiroApiErrors;
export 'src/model/wiro_task.dart';
export 'src/wiro_client.dart';
export 'src/wiro_exception.dart';
export 'src/wiro_request.dart';
