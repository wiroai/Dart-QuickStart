import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Aspect ratio accepted by [WiroRunwayGen45Request].
///
/// Wire values were taken from the `runway/gen-4-5` schema on 2026-07-24.
enum WiroRunwayGen45Ratio {
  /// Matches the input image, or `16:9` for text-to-video runs.
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

  /// Ultra-wide 21:9.
  ultrawide21x9('21:9');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroRunwayGen45Ratio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Public-figure moderation threshold for [WiroRunwayGen45Request].
enum WiroRunwayGen45Moderation {
  /// Provider-selected moderation threshold.
  auto('auto'),

  /// Low moderation threshold. This is the model default.
  low('low');

  /// Creates a moderation threshold with its Wiro wire value.
  const WiroRunwayGen45Moderation(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `runway/gen-4-5` video model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24. Unknown or newer parameters can still be sent through the
/// dynamic `WiroClient.runModel` API.
final class WiroRunwayGen45Request implements WiroModelRequest {
  /// Creates a Runway Gen-4.5 video generation request.
  ///
  /// [prompt], [ratio], and [duration] are required; the rest falls back
  /// to the model's server-side default when omitted. Out-of-range values
  /// fail with a descriptive assertion in debug builds.
  ///
  /// ```dart
  /// const WiroRunwayGen45Request(
  ///   prompt: 'A drone shot over a rugged coastline',
  ///   ratio: WiroRunwayGen45Ratio.landscape16x9,
  ///   duration: 5,
  /// );
  /// ```
  const WiroRunwayGen45Request({
    required this.prompt,
    required this.ratio,
    required this.duration,
    this.inputImages,
    this.contentModeration,
    this.seed,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(prompt.length <= 1000, 'prompt cannot exceed 1000 characters'),
       assert(duration > 0, 'duration must be positive'),
       assert(
         seed == null || (seed >= 0 && seed <= 4294967295),
         'seed must be between 0 and 4294967295',
       );

  /// Video description; at most 1000 characters.
  final String prompt;

  /// Aspect ratio of the generated video.
  final WiroRunwayGen45Ratio ratio;

  /// Video duration in seconds; 2 to 10 seconds under current pricing.
  final int duration;

  /// Optional first-frame image URLs for image-to-video runs.
  final List<WiroFileInput>? inputImages;

  /// Optional public-figure moderation threshold.
  final WiroRunwayGen45Moderation? contentModeration;

  /// Optional fixed seed (0 to 4294967295) for reproducible results.
  final int? seed;

  @override
  WiroModelId get model => WiroModelId('runway', 'gen-4-5');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'ratio': ratio.apiValue,
      'duration': duration,
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
      'contentModeration': ?contentModeration?.apiValue,
      'seed': ?seed,
    };
  }
}
