import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Aspect ratio accepted by [WiroGrokImagineImageRequest].
///
/// Wire values were taken from the `xai/grok-imagine-image` schema on
/// 2026-07-24.
enum WiroGrokImagineImageRatio {
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
  portrait2x3('2:3'),

  /// Landscape 2:1.
  landscape2x1('2:1'),

  /// Portrait 1:2.
  portrait1x2('1:2'),

  /// Phone landscape 19.5:9.
  landscape19_5x9('19.5:9'),

  /// Phone portrait 9:19.5.
  portrait9x19_5('9:19.5'),

  /// Phone landscape 20:9.
  landscape20x9('20:9'),

  /// Phone portrait 9:20.
  portrait9x20('9:20');

  /// Creates an aspect ratio with its Wiro wire value.
  const WiroGrokImagineImageRatio(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Output resolution accepted by [WiroGrokImagineImageRequest].
enum WiroGrokImagineImageResolution {
  /// 1K output.
  r1k('1k'),

  /// 2K output.
  r2k('2k');

  /// Creates a resolution with its Wiro wire value.
  const WiroGrokImagineImageResolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `xai/grok-imagine-image` image model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroGrokImagineImageRequest implements WiroModelRequest {
  /// Creates a Grok Imagine Image generation or edit request.
  ///
  /// [prompt], [samples], and [resolution] are required. [aspectRatio]
  /// applies to text-to-image runs; edits keep the input image's ratio.
  ///
  /// ```dart
  /// const WiroGrokImagineImageRequest(
  ///   prompt: 'A neon-lit alley in the rain',
  ///   samples: 1,
  ///   resolution: WiroGrokImagineImageResolution.r1k,
  /// );
  /// ```
  const WiroGrokImagineImageRequest({
    required this.prompt,
    required this.samples,
    required this.resolution,
    this.inputImages,
    this.aspectRatio,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(
         samples >= 1 && samples <= 10,
         'samples must be between 1 and 10',
       ),
       assert(
         inputImages == null || inputImages.length <= 1,
         'inputImages accepts at most one image',
       );

  /// Text description of the desired image or edit.
  final String prompt;

  /// Number of images to generate; 1 to 10.
  final int samples;

  /// Output image resolution.
  final WiroGrokImagineImageResolution resolution;

  /// Optional source image URL for editing; at most one, max 20 MiB
  /// (jpg, jpeg, png).
  final List<WiroFileInput>? inputImages;

  /// Optional aspect ratio for text-to-image runs.
  final WiroGrokImagineImageRatio? aspectRatio;

  @override
  WiroModelId get model => WiroModelId('xai', 'grok-imagine-image');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'samples': samples,
      'resolution': resolution.apiValue,
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
      'aspectRatio': ?aspectRatio?.apiValue,
    };
  }
}
