import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Video mode accepted by [WiroKlingV3Request].
///
/// Wire values were taken from the `klingai/kling-v3` schema on
/// 2026-07-24.
enum WiroKlingV3Mode {
  /// Standard 720p output.
  std('std'),

  /// Pro 1080p output.
  pro('pro'),

  /// Native 4K output with pro-level expressiveness.
  ultra4k('4k');

  /// Creates a video mode with its Wiro wire value.
  const WiroKlingV3Mode(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Aspect ratio accepted by [WiroKlingV3Request].
enum WiroKlingV3Ratio {
  /// Landscape 16:9.
  landscape16x9('16:9'),

  /// Portrait 9:16.
  portrait9x16('9:16'),

  /// Square 1:1.
  square('1:1');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroKlingV3Ratio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Multi-shot type accepted by [WiroKlingV3Request].
enum WiroKlingV3ShotType {
  /// Uses [WiroKlingV3Request.multiPrompt] for per-shot control.
  customize('customize'),

  /// Lets the model split [WiroKlingV3Request.prompt] into shots.
  intelligence('intelligence');

  /// Creates a shot type with its Wiro wire value.
  const WiroKlingV3ShotType(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `klingai/kling-v3` video model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroKlingV3Request implements WiroModelRequest {
  /// Creates a Kling V3 video generation request.
  ///
  /// [mode], [duration] (5, 10, or 15 seconds), [ratio], and [sound]
  /// are required. [ratio] only applies to text-to-video runs, and
  /// sound is disabled when [lastFrameImage] is provided.
  ///
  /// ```dart
  /// const WiroKlingV3Request(
  ///   prompt: 'A paper boat drifting down a rainy street',
  ///   mode: WiroKlingV3Mode.std,
  ///   duration: 5,
  ///   ratio: WiroKlingV3Ratio.landscape16x9,
  ///   sound: false,
  /// );
  /// ```
  const WiroKlingV3Request({
    required this.mode,
    required this.duration,
    required this.ratio,
    required this.sound,
    this.prompt,
    this.inputImage,
    this.lastFrameImage,
    this.multiShot,
    this.shotType,
    this.multiPrompt,
  }) : assert(
         duration == 5 || duration == 10 || duration == 15,
         'duration must be 5, 10, or 15 seconds',
       ),
       assert(
         multiShot != true ||
             shotType != WiroKlingV3ShotType.customize ||
             multiPrompt != null,
         'multiPrompt is required when shotType is customize',
       );

  /// Video mode controlling the output resolution.
  final WiroKlingV3Mode mode;

  /// Total duration of the generated video in seconds; 5, 10, or 15.
  final int duration;

  /// Aspect ratio; only applies to text-to-video runs.
  final WiroKlingV3Ratio ratio;

  /// Whether the video includes sound; forced off when
  /// [lastFrameImage] is provided.
  final bool sound;

  /// Optional text prompt for the video.
  final String? prompt;

  /// Optional first-frame image URLs.
  final List<WiroFileInput>? inputImage;

  /// Optional last-frame image URLs; disables sound.
  final List<WiroFileInput>? lastFrameImage;

  /// Optional multi-shot video generation toggle.
  final bool? multiShot;

  /// Optional shot type; required when [multiShot] is `true`.
  final WiroKlingV3ShotType? shotType;

  /// Optional multi-prompt JSON string; required when [shotType] is
  /// [WiroKlingV3ShotType.customize]. Must be an array of objects with
  /// `index`, `prompt`, and `duration` fields.
  final String? multiPrompt;

  @override
  WiroModelId get model => WiroModelId('klingai', 'kling-v3');

  @override
  WiroJson toJson() {
    return {
      'mode': mode.apiValue,
      'duration': '$duration',
      'ratio': ratio.apiValue,
      'sound': sound ? 'on' : 'off',
      'prompt': ?prompt,
      'inputImage': ?inputImage?.map((file) => file.wireValue).toList(),
      'inputImage2': ?lastFrameImage?.map((file) => file.wireValue).toList(),
      'multiShot': multiShot == null ? null : '$multiShot',
      'shotType': ?shotType?.apiValue,
      'multiPrompt': ?multiPrompt,
    }..removeWhere((key, value) => value == null);
  }
}
