import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Aspect ratio accepted by [WiroGrokImagineVideoRequest].
///
/// Wire values were taken from the `xai/grok-imagine-video` schema on
/// 2026-07-24.
enum WiroGrokImagineVideoRatio {
  /// Matches the input image, or 16:9 for text-to-video runs.
  auto('auto'),

  /// Landscape 16:9.
  landscape16x9('16:9'),

  /// Portrait 9:16.
  portrait9x16('9:16'),

  /// Square 1:1.
  square('1:1'),

  /// Standard 4:3.
  standard4x3('4:3'),

  /// Portrait 3:4.
  portrait3x4('3:4'),

  /// Landscape 3:2.
  landscape3x2('3:2'),

  /// Portrait 2:3.
  portrait2x3('2:3');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroGrokImagineVideoRatio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Video resolution accepted by [WiroGrokImagineVideoRequest].
enum WiroGrokImagineVideoResolution {
  /// 480p output; cheapest tier.
  r480p('480p'),

  /// 720p output.
  r720p('720p');

  /// Creates a resolution with its Wiro wire value.
  const WiroGrokImagineVideoResolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `xai/grok-imagine-video` video model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroGrokImagineVideoRequest implements WiroModelRequest {
  /// Creates a Grok Imagine Video generation request.
  ///
  /// [prompt], [duration] (5, 10, or 15 seconds), [aspectRatio], and
  /// [resolution] are required. Videos include native audio.
  ///
  /// ```dart
  /// const WiroGrokImagineVideoRequest(
  ///   prompt: 'A drone shot over a rugged coastline',
  ///   duration: 5,
  ///   aspectRatio: WiroGrokImagineVideoRatio.landscape16x9,
  ///   resolution: WiroGrokImagineVideoResolution.r480p,
  /// );
  /// ```
  const WiroGrokImagineVideoRequest({
    required this.prompt,
    required this.duration,
    required this.aspectRatio,
    required this.resolution,
    this.inputImages,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(
         duration == 5 || duration == 10 || duration == 15,
         'duration must be 5, 10, or 15 seconds',
       ),
       assert(
         inputImages == null || inputImages.length <= 1,
         'inputImages accepts at most one image',
       );

  /// Text description of the desired video.
  final String prompt;

  /// Video duration in seconds; 5, 10, or 15.
  final int duration;

  /// Aspect ratio; `auto` follows the input image when provided.
  final WiroGrokImagineVideoRatio aspectRatio;

  /// Video resolution.
  final WiroGrokImagineVideoResolution resolution;

  /// Optional first-frame image URL for image-to-video runs; at most
  /// one, max 20 MiB (jpg, jpeg, png).
  final List<WiroFileInput>? inputImages;

  @override
  WiroModelId get model => WiroModelId('xai', 'grok-imagine-video');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'duration': '$duration',
      'aspectRatio': aspectRatio.apiValue,
      'resolution': resolution.apiValue,
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
    };
  }
}
