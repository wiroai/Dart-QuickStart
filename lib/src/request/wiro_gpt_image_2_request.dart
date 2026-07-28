import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Output resolution tier accepted by [WiroGptImage2Request].
///
/// Wire values were taken from the `openai/gpt-image-2` schema on
/// 2026-07-24.
enum WiroGptImage2Resolution {
  /// 1K output.
  r1k('1k'),

  /// 2K output.
  r2k('2k'),

  /// 4K output.
  r4k('4k');

  /// Creates a resolution with its Wiro wire value.
  const WiroGptImage2Resolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Aspect ratio accepted by [WiroGptImage2Request].
enum WiroGptImage2Ratio {
  /// Square 1:1.
  square('1:1'),

  /// Landscape 3:2.
  landscape3x2('3:2'),

  /// Portrait 2:3.
  portrait2x3('2:3'),

  /// Standard 4:3.
  standard4x3('4:3'),

  /// Portrait 3:4.
  portrait3x4('3:4'),

  /// Landscape 16:9.
  landscape16x9('16:9'),

  /// Portrait 9:16.
  portrait9x16('9:16');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroGptImage2Ratio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Output image quality accepted by [WiroGptImage2Request].
enum WiroGptImage2Quality {
  /// Low quality; cheapest tier.
  low('low'),

  /// Medium quality.
  medium('medium'),

  /// High quality.
  high('high');

  /// Creates a quality with its Wiro wire value.
  const WiroGptImage2Quality(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Background setting accepted by [WiroGptImage2Request].
enum WiroGptImage2Background {
  /// Provider-selected background.
  auto('auto'),

  /// Opaque background.
  opaque('opaque');

  /// Creates a background setting with its Wiro wire value.
  const WiroGptImage2Background(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Output format accepted by [WiroGptImage2Request].
enum WiroGptImage2OutputFormat {
  /// PNG output. This is the model default.
  png('png'),

  /// JPEG output.
  jpeg('jpeg'),

  /// WebP output.
  webp('webp');

  /// Creates an output format with its Wiro wire value.
  const WiroGptImage2OutputFormat(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Content moderation level accepted by [WiroGptImage2Request].
enum WiroGptImage2Moderation {
  /// Provider-selected moderation level.
  auto('auto'),

  /// Low moderation level.
  low('low');

  /// Creates a moderation level with its Wiro wire value.
  const WiroGptImage2Moderation(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `openai/gpt-image-2` image model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroGptImage2Request implements WiroModelRequest {
  /// Creates a GPT Image 2 generation or edit request.
  ///
  /// [prompt], [resolution], [ratio], [quality], and [samples] are
  /// required; the rest falls back to the model's server-side default
  /// when omitted.
  ///
  /// ```dart
  /// const WiroGptImage2Request(
  ///   prompt: 'A studio product shot of a ceramic mug',
  ///   resolution: WiroGptImage2Resolution.r1k,
  ///   ratio: WiroGptImage2Ratio.square,
  ///   quality: WiroGptImage2Quality.low,
  ///   samples: 1,
  /// );
  /// ```
  const WiroGptImage2Request({
    required this.prompt,
    required this.resolution,
    required this.ratio,
    required this.quality,
    required this.samples,
    this.inputImages,
    this.inputImageMasks,
    this.background,
    this.outputFormat,
    this.outputCompression,
    this.moderation,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(
         prompt.length <= 32000,
         'prompt cannot exceed 32000 characters',
       ),
       assert(
         samples >= 1 && samples <= 10,
         'samples must be between 1 and 10',
       ),
       assert(
         outputCompression == null ||
             (outputCompression >= 0 && outputCompression <= 100),
         'outputCompression must be between 0 and 100',
       );

  /// Text description of the desired image or edit; at most 32,000
  /// characters.
  final String prompt;

  /// Output resolution tier.
  final WiroGptImage2Resolution resolution;

  /// Aspect ratio of the output image.
  final WiroGptImage2Ratio ratio;

  /// Output image quality.
  final WiroGptImage2Quality quality;

  /// Number of images to generate; 1 to 10.
  final int samples;

  /// Optional input image URLs to edit, up to 16.
  final List<WiroFileInput>? inputImages;

  /// Optional mask image URLs defining areas to edit; requires
  /// [inputImages].
  final List<WiroFileInput>? inputImageMasks;

  /// Optional background setting.
  final WiroGptImage2Background? background;

  /// Optional output format. Defaults to PNG on the server.
  final WiroGptImage2OutputFormat? outputFormat;

  /// Optional compression level (0-100) for JPEG or WebP output.
  /// Defaults to 100 on the server.
  final int? outputCompression;

  /// Optional content moderation level.
  final WiroGptImage2Moderation? moderation;

  @override
  WiroModelId get model => WiroModelId('openai', 'gpt-image-2');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'resolution': resolution.apiValue,
      'ratio': ratio.apiValue,
      'quality': quality.apiValue,
      'samples': samples,
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
      'inputImageMask': ?inputImageMasks
          ?.map((file) => file.wireValue)
          .toList(),
      'background': ?background?.apiValue,
      'outputFormat': ?outputFormat?.apiValue,
      'outputCompression': ?outputCompression,
      'moderation': ?moderation?.apiValue,
    };
  }
}
