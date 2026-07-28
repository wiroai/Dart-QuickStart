import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Video resolution accepted by [WiroSeedance20Request].
///
/// Wire values were taken from the `bytedance/seedance-2-0` schema on
/// 2026-07-24.
enum WiroSeedance20Resolution {
  /// 480p output; cheapest tier.
  r480p('480p'),

  /// 720p output.
  r720p('720p'),

  /// 1080p output.
  r1080p('1080p'),

  /// 4K output.
  r4k('4k');

  /// Creates a resolution with its Wiro wire value.
  const WiroSeedance20Resolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Aspect ratio accepted by [WiroSeedance20Request].
enum WiroSeedance20Ratio {
  /// Model-selected ratio based on prompt and input images.
  adaptive('adaptive'),

  /// Landscape 16:9.
  landscape16x9('16:9'),

  /// Standard 4:3.
  standard4x3('4:3'),

  /// Square 1:1.
  square('1:1'),

  /// Portrait 3:4.
  portrait3x4('3:4'),

  /// Portrait 9:16.
  portrait9x16('9:16'),

  /// Ultra-wide 21:9.
  ultrawide21x9('21:9');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroSeedance20Ratio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `bytedance/seedance-2-0` video model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroSeedance20Request implements WiroModelRequest {
  /// Creates a Seedance 2.0 video generation request.
  ///
  /// [resolution], [ratio], [duration] (4 to 15 seconds), and
  /// [generateAudio] are required. Provide a [prompt], [inputImage]
  /// (first frame), or [referenceImages] to steer the video.
  ///
  /// ```dart
  /// const WiroSeedance20Request(
  ///   prompt: 'A time-lapse of a city waking up',
  ///   resolution: WiroSeedance20Resolution.r480p,
  ///   ratio: WiroSeedance20Ratio.landscape16x9,
  ///   duration: 4,
  ///   generateAudio: false,
  /// );
  /// ```
  const WiroSeedance20Request({
    required this.resolution,
    required this.ratio,
    required this.duration,
    required this.generateAudio,
    this.prompt,
    this.inputImage,
    this.lastFrameImage,
    this.referenceImages,
    this.referenceAudios,
    this.promptEnhancement,
    this.watermark,
    this.seed,
  }) : assert(
         duration >= 4 && duration <= 15,
         'duration must be between 4 and 15 seconds',
       ),
       assert(
         referenceImages == null ||
             (referenceImages.length >= 1 && referenceImages.length <= 9),
         'referenceImages accepts 1 to 9 images',
       ),
       assert(
         referenceAudios == null ||
             (referenceAudios.length >= 1 && referenceAudios.length <= 3),
         'referenceAudios accepts 1 to 3 audio files',
       ),
       assert(seed == null || seed >= 0, 'seed cannot be negative');

  /// Video resolution.
  final WiroSeedance20Resolution resolution;

  /// Output aspect ratio.
  final WiroSeedance20Ratio ratio;

  /// Video duration in seconds; 4 to 15.
  final int duration;

  /// Whether the video includes audio synchronized with the visuals.
  final bool generateAudio;

  /// Optional text prompt for the video.
  final String? prompt;

  /// Optional first-frame image URLs for image-to-video runs.
  final List<WiroFileInput>? inputImage;

  /// Optional last-frame image URLs; requires [inputImage].
  final List<WiroFileInput>? lastFrameImage;

  /// Optional reference image URLs (1 to 9); refer to them in the
  /// prompt as `[Image 1]`, `[Image 2]`, and so on.
  final List<WiroFileInput>? referenceImages;

  /// Optional reference audio URLs (1 to 3, wav or mp3); requires a
  /// reference image and cannot be combined with first or last frames.
  final List<WiroFileInput>? referenceAudios;

  /// Optional AI prompt rewrite that reduces content-filter failures.
  /// Recommended when [generateAudio] is `true`.
  final bool? promptEnhancement;

  /// Optional watermark toggle.
  final bool? watermark;

  /// Optional seed; `0` selects a random seed.
  final int? seed;

  @override
  WiroModelId get model => WiroModelId('bytedance', 'seedance-2-0');

  @override
  WiroJson toJson() {
    return {
      'resolution': resolution.apiValue,
      'ratio': ratio.apiValue,
      'duration': '$duration',
      'generateAudio': '$generateAudio',
      'prompt': ?prompt,
      'inputImage': ?inputImage?.map((file) => file.wireValue).toList(),
      'inputImageLast': ?lastFrameImage?.map((file) => file.wireValue).toList(),
      'inputImageReference': ?referenceImages
          ?.map((file) => file.wireValue)
          .toList(),
      'inputAudio': ?referenceAudios?.map((file) => file.wireValue).toList(),
      'promptEnhancement': promptEnhancement == null
          ? null
          : '$promptEnhancement',
      'watermark': watermark == null ? null : '$watermark',
      'seed': ?seed,
    }..removeWhere((key, value) => value == null);
  }
}
