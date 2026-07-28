import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Output size accepted by [WiroSeedreamV4Request].
///
/// Wire values were taken from the `bytedance/seedream-v4` schema on
/// 2026-07-24.
enum WiroSeedreamV4Size {
  /// Square 2048x2048.
  square2048('2048x2048'),

  /// Landscape 2304x1728.
  landscape2304x1728('2304x1728'),

  /// Portrait 1728x2304.
  portrait1728x2304('1728x2304'),

  /// Landscape 2560x1440.
  landscape2560x1440('2560x1440'),

  /// Portrait 1440x2560.
  portrait1440x2560('1440x2560'),

  /// Landscape 2496x1664.
  landscape2496x1664('2496x1664'),

  /// Portrait 1664x2496.
  portrait1664x2496('1664x2496'),

  /// Panorama 3024x1296.
  panorama3024x1296('3024x1296');

  /// Creates an output size with its Wiro wire value.
  const WiroSeedreamV4Size(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `bytedance/seedream-v4` image model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroSeedreamV4Request implements WiroModelRequest {
  /// Creates a Seedream v4 generation or edit request.
  ///
  /// [prompt], [size], [maxImages], and [watermark] are required.
  /// State the desired number of images in the prompt and cap it with
  /// [maxImages]; input references plus outputs cannot exceed 15.
  ///
  /// ```dart
  /// const WiroSeedreamV4Request(
  ///   prompt: 'Generate one poster of a retro sports car',
  ///   size: WiroSeedreamV4Size.square2048,
  ///   maxImages: 1,
  ///   watermark: false,
  /// );
  /// ```
  const WiroSeedreamV4Request({
    required this.prompt,
    required this.size,
    required this.maxImages,
    required this.watermark,
    this.inputImages,
  }) : assert(prompt != '', 'prompt cannot be empty'),
       assert(
         maxImages >= 1 && maxImages <= 15,
         'maxImages must be between 1 and 15',
       );

  /// Text prompt; also state how many images you want generated.
  final String prompt;

  /// Output resolution of the generated image(s).
  final WiroSeedreamV4Size size;

  /// Maximum number of output images; input references plus outputs
  /// cannot exceed 15.
  final int maxImages;

  /// Whether the generated image(s) contain a watermark.
  final bool watermark;

  /// Optional input image URLs for creating, editing, or combining.
  final List<WiroFileInput>? inputImages;

  @override
  WiroModelId get model => WiroModelId('bytedance', 'seedream-v4');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'size': size.apiValue,
      'maxImages': maxImages,
      'watermark': '$watermark',
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
    };
  }
}
