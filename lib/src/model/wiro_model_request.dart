import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';

/// A model paired with its typed, serializable parameters.
///
/// Implementations bundle a [model] identifier with the parameter map that
/// model expects, so callers get compile-time checked inputs while the
/// transport stays schema-agnostic. The SDK ships typed requests for
/// popular models; any model can be wrapped by implementing this interface.
abstract interface class WiroModelRequest {
  /// Model that executes this request.
  WiroModelId get model;

  /// Serializes the typed parameters into the Wiro wire format.
  WiroJson toJson();
}
