// GENERATED CODE - do not edit by hand.
//
// Model: google/upscaler
// Schema snapshot: 2026-07-24
// Regenerate: dart run tool/generate.dart google/upscaler

import 'package:wiro_client/wiro_client.dart';

/// Output Format accepted by [WiroUpscalerRequest].
enum WiroUpscalerOutputType {
  /// Wire value `png`.
  png('png'),

  /// Wire value `jpeg`.
  jpeg('jpeg');

  /// Creates a value with its Wiro wire value.
  const WiroUpscalerOutputType(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `google/upscaler` model.
///
/// Upscaler by Google (Imagen Upscale)
///
/// Generated from the live Wiro schema on 2026-07-24.
final class WiroUpscalerRequest implements WiroModelRequest {
  /// Creates a `google/upscaler` request.
  const WiroUpscalerRequest({
    required this.inputImage,
    required this.upscaleFactor,
    required this.outputType,
    this.compressionQuality,
  });

  /// Input Image Required. The image to upscale. Output resolution (input
  /// resolution × upscale factor) must not exceed 17 megapixels.
  final List<WiroFileInput> inputImage;

  /// Upscale Factor Required. Scaling factor for the upscaled image. Final
  /// resolution must not exceed 17 megapixels.
  final int upscaleFactor;

  /// Output Format Required. Output image file type. Defaults to PNG.
  final WiroUpscalerOutputType outputType;

  /// Compression Quality Optional. JPEG detail level (0-100). Only applies
  /// when Output Format is JPEG. Default 75.
  final int? compressionQuality;

  @override
  WiroModelId get model => WiroModelId('google', 'upscaler');

  @override
  WiroJson toJson() {
    return <String, Object?>{
      'inputImage': inputImage.map((file) => file.wireValue).toList(),
      'upscaleFactor': upscaleFactor,
      'outputType': outputType.apiValue,
      'compressionQuality': compressionQuality,
    }..removeWhere((key, value) => value == null);
  }
}
