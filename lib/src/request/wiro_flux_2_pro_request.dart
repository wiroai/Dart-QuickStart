import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Output format accepted by [WiroFlux2ProRequest].
///
/// Wire values were taken from the `black-forest-labs/flux-2-pro` schema
/// on 2026-07-24.
enum WiroFlux2ProOutputFormat {
  /// JPEG output.
  jpeg('jpeg'),

  /// PNG output.
  png('png');

  /// Creates an output format with its Wiro wire value.
  const WiroFlux2ProOutputFormat(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `black-forest-labs/flux-2-pro` image model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24. Unknown or newer parameters can still be sent through the
/// dynamic `WiroClient.runModel` API.
final class WiroFlux2ProRequest implements WiroModelRequest {
  /// Creates a Flux 2 Pro image generation request.
  ///
  /// Only [prompt] is required; every other parameter falls back to the
  /// model's server-side default when omitted. Out-of-range values fail
  /// with a descriptive assertion in debug builds.
  ///
  /// ```dart
  /// const WiroFlux2ProRequest(
  ///   prompt: 'A cinematic mountain lake',
  ///   width: 1024,
  ///   height: 1024,
  /// );
  /// ```
  const WiroFlux2ProRequest({
    required this.prompt,
    this.inputImages,
    this.width,
    this.height,
    this.safetyTolerance,
    this.seed,
    this.outputFormat,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(
         width == null ||
             width == 0 ||
             (width >= 64 && width <= 2048 && width % 16 == 0),
         'width must be 0 or a multiple of 16 between 64 and 2048',
       ),
       assert(
         height == null ||
             height == 0 ||
             (height >= 64 && height <= 2048 && height % 16 == 0),
         'height must be 0 or a multiple of 16 between 64 and 2048',
       ),
       assert(
         safetyTolerance == null ||
             (safetyTolerance >= 0 && safetyTolerance <= 5),
         'safetyTolerance must be between 0 and 5',
       ),
       assert(seed == null || seed >= 0, 'seed cannot be negative');

  /// Text prompt for image generation.
  final String prompt;

  /// Optional input image URLs for image-to-image and editing runs.
  final List<WiroFileInput>? inputImages;

  /// Width in pixels; a multiple of 16 between 64 and 2048.
  ///
  /// Use `0` or `null` to match the input image.
  final int? width;

  /// Height in pixels; a multiple of 16 between 64 and 2048.
  ///
  /// Use `0` or `null` to match the input image.
  final int? height;

  /// Moderation tolerance from 0 (most strict) to 5 (least strict).
  final int? safetyTolerance;

  /// Seed for reproducible results.
  final int? seed;

  /// Output format for the generated image.
  final WiroFlux2ProOutputFormat? outputFormat;

  @override
  WiroModelId get model => WiroModelId('black-forest-labs', 'flux-2-pro');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
      'width': ?width,
      'height': ?height,
      'safetyTolerance': ?safetyTolerance,
      'seed': ?seed,
      'outputFormat': ?outputFormat?.apiValue,
    };
  }
}
