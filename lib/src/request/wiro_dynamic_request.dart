import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// A request for any Wiro model, with parameters supplied as a map.
///
/// Use this for models the SDK does not ship a typed request for. The
/// [parameters] map travels as-is, so any model works without waiting for
/// an SDK update. `WiroFileInput` values inside the map are still uploaded
/// automatically before the model runs.
///
/// ```dart
/// final result = await client.subscribeRequest(
///   Wiro.model('xai/grok-imagine-video', parameters: {
///     'prompt': 'A drone shot over snowy mountains',
///     'duration': '5',
///     'resolution': '480p',
///   }),
/// );
/// ```
///
/// Call `WiroClient.getModelSchema` to discover the parameters a model
/// accepts, and `WiroModelSchema.validate` to check the map locally
/// before a paid run starts.
final class WiroDynamicRequest implements WiroModelRequest {
  /// Creates a request for [model] with dynamic [parameters].
  WiroDynamicRequest(this.model, {required WiroJson parameters})
    : parameters = Map.unmodifiable(parameters);

  @override
  final WiroModelId model;

  /// Parameters sent to the model, in the Wiro wire format.
  final WiroJson parameters;

  @override
  WiroJson toJson() => parameters;
}
