/// Official Wiro AI SDK for Dart and Flutter.
///
/// Import this library to discover models, inspect their schemas, run model
/// tasks, upload inputs, and observe task progress:
///
/// ```dart
/// final client = WiroClient(apiKey: 'your-api-key');
/// try {
///   final models = await client.searchModels(search: 'image');
///   print(models.items.first.identifier);
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
