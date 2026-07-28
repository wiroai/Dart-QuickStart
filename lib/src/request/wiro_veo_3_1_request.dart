import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Aspect ratio accepted by [WiroVeo31Request].
///
/// Wire values were taken from the `google/veo3-1` schema on 2026-07-24.
enum WiroVeo31Ratio {
  /// Landscape 16:9.
  landscape16x9('16:9'),

  /// Portrait 9:16.
  portrait9x16('9:16'),

  /// Matches the input image's aspect ratio.
  matchInputImage('match_input_image');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroVeo31Ratio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Video resolution accepted by [WiroVeo31Request].
enum WiroVeo31Resolution {
  /// 720p output; cheapest tier.
  r720p('720p'),

  /// 1080p output.
  r1080p('1080p'),

  /// 4K output.
  r4k('4k');

  /// Creates a resolution with its Wiro wire value.
  const WiroVeo31Resolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `google/veo3-1` video model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroVeo31Request implements WiroModelRequest {
  /// Creates a Veo 3.1 video generation request.
  ///
  /// Only [durationSeconds] (4, 6, or 8) is required. Steer the video
  /// with a [prompt], [inputImage] (first frame), [lastFrameImage], or
  /// up to three [referenceImages]; reference images force an
  /// eight-second duration and ignore first and last frames.
  ///
  /// ```dart
  /// const WiroVeo31Request(
  ///   prompt: 'A hot air balloon drifting over vineyards at dawn',
  ///   durationSeconds: 4,
  /// );
  /// ```
  const WiroVeo31Request({
    required this.durationSeconds,
    this.prompt,
    this.inputImage,
    this.lastFrameImage,
    this.referenceImages,
    this.aspectRatio,
    this.resolution,
    this.negativePrompt,
    this.seed,
  }) : assert(
         durationSeconds == 4 || durationSeconds == 6 || durationSeconds == 8,
         'durationSeconds must be 4, 6, or 8',
       ),
       assert(
         referenceImages == null ||
             (referenceImages.length >= 1 && referenceImages.length <= 3),
         'referenceImages accepts 1 to 3 images',
       ),
       assert(seed == null || seed >= 0, 'seed cannot be negative');

  /// Duration of the generated video in seconds; 4, 6, or 8.
  final int durationSeconds;

  /// Optional text prompt for the video.
  final String? prompt;

  /// Optional first-frame image URLs.
  final List<WiroFileInput>? inputImage;

  /// Optional last-frame image URLs.
  final List<WiroFileInput>? lastFrameImage;

  /// Optional reference image URLs (1 to 3); forces an eight-second
  /// duration and ignores first and last frames.
  final List<WiroFileInput>? referenceImages;

  /// Optional aspect ratio of the generated video.
  final WiroVeo31Ratio? aspectRatio;

  /// Optional resolution of the generated video.
  final WiroVeo31Resolution? resolution;

  /// Optional description of anything to discourage in the video.
  final String? negativePrompt;

  /// Optional seed for deterministic output; omit for random results.
  final int? seed;

  @override
  WiroModelId get model => WiroModelId('google', 'veo3-1');

  @override
  WiroJson toJson() {
    return {
      'durationSeconds': '$durationSeconds',
      'prompt': ?prompt,
      'inputImage': ?inputImage?.map((file) => file.wireValue).toList(),
      'inputImage2': ?lastFrameImage?.map((file) => file.wireValue).toList(),
      'inputImage3': ?referenceImages?.map((file) => file.wireValue).toList(),
      'aspectRatio': ?aspectRatio?.apiValue,
      'resolution': ?resolution?.apiValue,
      'negativePrompt': ?negativePrompt,
      'seed': ?seed,
    };
  }
}
