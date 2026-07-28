import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Video resolution accepted by [WiroSora2ProRequest].
///
/// Wire values were taken from the `openai/sora-2-pro` schema on
/// 2026-07-24.
enum WiroSora2ProResolution {
  /// 720p output; cheapest tier.
  r720p('720p'),

  /// 1024p output.
  r1024p('1024p'),

  /// 1080p output.
  r1080p('1080p');

  /// Creates a resolution with its Wiro wire value.
  const WiroSora2ProResolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Aspect ratio accepted by [WiroSora2ProRequest].
enum WiroSora2ProRatio {
  /// Landscape 16:9. This is the default without an input image.
  landscape16x9('16:9'),

  /// Portrait 9:16.
  portrait9x16('9:16'),

  /// Detects the input image's ratio and picks the closest option.
  auto('auto');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroSora2ProRatio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `openai/sora-2-pro` video model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroSora2ProRequest implements WiroModelRequest {
  /// Creates a Sora 2 Pro video generation request.
  ///
  /// [prompt] and [seconds] (4, 8, 12, 16, or 20) are required; the
  /// rest falls back to the model's server-side default when omitted.
  ///
  /// ```dart
  /// const WiroSora2ProRequest(
  ///   prompt: 'A whale breaching in slow motion at golden hour',
  ///   seconds: 4,
  /// );
  /// ```
  const WiroSora2ProRequest({
    required this.prompt,
    required this.seconds,
    this.inputImages,
    this.resolution,
    this.ratio,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(
         seconds == 4 ||
             seconds == 8 ||
             seconds == 12 ||
             seconds == 16 ||
             seconds == 20,
         'seconds must be 4, 8, 12, 16, or 20',
       );

  /// Text prompt for the video.
  final String prompt;

  /// Duration of the video in seconds; 4, 8, 12, 16, or 20.
  final int seconds;

  /// Optional input image URLs.
  final List<WiroFileInput>? inputImages;

  /// Optional resolution of the generated video.
  final WiroSora2ProResolution? resolution;

  /// Optional aspect ratio of the generated video.
  final WiroSora2ProRatio? ratio;

  @override
  WiroModelId get model => WiroModelId('openai', 'sora-2-pro');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'seconds': '$seconds',
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
      'resolution': ?resolution?.apiValue,
      'ratio': ?ratio?.apiValue,
    };
  }
}
