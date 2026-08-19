/// Official Wiro AI SDK for Dart and Flutter.
///
/// Import this library to discover models, inspect their schemas, run model
/// tasks, upload inputs, and observe task progress:
///
/// ```dart
/// final client = WiroClient(apiKey: 'your-api-key');
/// try {
///   final result = await client.subscribe(
///     WiroModelId('black-forest-labs', 'flux-2-pro'),
///     parameters: {'prompt': 'A cinematic mountain lake'},
///   );
///   print(result.task.outputs.first.url);
/// } finally {
///   client.close();
/// }
/// ```
library;

export 'src/model/wiro_file_input.dart';
export 'src/model/wiro_identifier.dart';
export 'src/model/wiro_json.dart';
export 'src/model/wiro_model.dart';
export 'src/model/wiro_model_request.dart';
export 'src/model/wiro_result.dart' hide parseWiroApiErrors;
export 'src/model/wiro_socket.dart';
export 'src/model/wiro_task.dart';
export 'src/model/wiro_task_update.dart';
export 'src/request/wiro_dynamic_request.dart';
export 'src/request/wiro_flux_2_pro_request.dart';
export 'src/request/wiro_gpt_image_2_request.dart';
export 'src/request/wiro_grok_imagine_image_request.dart';
export 'src/request/wiro_grok_imagine_video_request.dart';
export 'src/request/wiro_hailuo_2_3_fast_request.dart';
export 'src/request/wiro_kling_v3_request.dart';
export 'src/request/wiro_lyria_3_request.dart';
export 'src/request/wiro_nano_banana_pro_request.dart';
export 'src/request/wiro_requests.dart';
export 'src/request/wiro_runway_gen_4_5_request.dart';
export 'src/request/wiro_seedance_2_0_request.dart';
export 'src/request/wiro_seedream_v4_request.dart';
export 'src/request/wiro_sora_2_pro_request.dart';
export 'src/request/wiro_veo_3_1_request.dart';
export 'src/wiro_client.dart';
export 'src/wiro_exception.dart';
export 'src/wiro_request.dart';
