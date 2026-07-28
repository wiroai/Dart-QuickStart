import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Aspect ratio accepted by [WiroNanoBananaProRequest].
///
/// Wire values were taken from the `google/nano-banana-pro` schema on
/// 2026-07-24.
enum WiroNanoBananaProRatio {
  /// Square 1:1.
  square('1:1'),

  /// Portrait 2:3.
  portrait2x3('2:3'),

  /// Landscape 3:2.
  landscape3x2('3:2'),

  /// Portrait 3:4.
  portrait3x4('3:4'),

  /// Standard 4:3.
  standard4x3('4:3'),

  /// Portrait 4:5.
  portrait4x5('4:5'),

  /// Landscape 5:4.
  landscape5x4('5:4'),

  /// Portrait 9:16.
  portrait9x16('9:16'),

  /// Landscape 16:9.
  landscape16x9('16:9'),

  /// Ultra-wide 21:9.
  ultrawide21x9('21:9');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroNanoBananaProRatio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Output resolution accepted by [WiroNanoBananaProRequest].
enum WiroNanoBananaProResolution {
  /// 1K output. This is the model default.
  r1k('1K'),

  /// 2K output.
  r2k('2K'),

  /// 4K output.
  r4k('4K');

  /// Creates a resolution with its Wiro wire value.
  const WiroNanoBananaProResolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Safety setting accepted by [WiroNanoBananaProRequest].
enum WiroNanoBananaProSafetySetting {
  /// Blocks low-probability unsafe content and above.
  blockLowAndAbove('BLOCK_LOW_AND_ABOVE'),

  /// Blocks medium-probability unsafe content and above.
  blockMediumAndAbove('BLOCK_MEDIUM_AND_ABOVE'),

  /// Blocks only high-probability unsafe content.
  blockOnlyHigh('BLOCK_ONLY_HIGH'),

  /// Disables blocking but keeps safety scoring.
  blockNone('BLOCK_NONE'),

  /// Disables the safety filter entirely.
  off('OFF');

  /// Creates a safety setting with its Wiro wire value.
  const WiroNanoBananaProSafetySetting(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `google/nano-banana-pro` image model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroNanoBananaProRequest implements WiroModelRequest {
  /// Creates a Nano Banana Pro generation or edit request.
  ///
  /// Only [prompt] is required; every other parameter falls back to the
  /// model's server-side default when omitted.
  ///
  /// ```dart
  /// const WiroNanoBananaProRequest(
  ///   prompt: 'A watercolor fox in a misty forest',
  /// );
  /// ```
  const WiroNanoBananaProRequest({
    required this.prompt,
    this.inputImages,
    this.aspectRatio,
    this.resolution,
    this.safetySetting,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(
         inputImages == null || inputImages.length <= 14,
         'inputImages cannot exceed 14 references',
       );

  /// Text prompt for image generation or editing.
  final String prompt;

  /// Optional reference image URLs, up to 14.
  final List<WiroFileInput>? inputImages;

  /// Optional aspect ratio of the output image.
  final WiroNanoBananaProRatio? aspectRatio;

  /// Optional output resolution. Defaults to 1K on the server.
  final WiroNanoBananaProResolution? resolution;

  /// Optional safety setting.
  final WiroNanoBananaProSafetySetting? safetySetting;

  @override
  WiroModelId get model => WiroModelId('google', 'nano-banana-pro');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
      'aspectRatio': ?aspectRatio?.apiValue,
      'resolution': ?resolution?.apiValue,
      'safetySetting': ?safetySetting?.apiValue,
    };
  }
}
