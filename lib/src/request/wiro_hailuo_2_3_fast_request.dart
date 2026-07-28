import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Video resolution accepted by [WiroHailuo23FastRequest].
///
/// Wire values were taken from the `minimax/hailuo-2-3-fast` schema on
/// 2026-07-24.
enum WiroHailuo23FastResolution {
  /// 768P output; supports 6- and 10-second videos.
  r768p('768P'),

  /// 1080P output; limited to 6-second videos.
  r1080p('1080P');

  /// Creates a resolution with its Wiro wire value.
  const WiroHailuo23FastResolution(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Typed request for the `minimax/hailuo-2-3-fast` video model.
///
/// Field constraints mirror the model schema published by Wiro on
/// 2026-07-24.
final class WiroHailuo23FastRequest implements WiroModelRequest {
  /// Creates a Hailuo 2.3 Fast image-to-video request.
  ///
  /// [inputImages] (the first frame) and [duration] (6 or 10 seconds)
  /// are required. The output keeps the input image's aspect ratio,
  /// and 10-second videos are only available at 768P.
  ///
  /// ```dart
  /// WiroHailuo23FastRequest(
  ///   inputImages: [Uri.parse('https://example.com/frame.png')],
  ///   duration: 6,
  ///   prompt: 'The camera slowly pans across the scene',
  /// );
  /// ```
  const WiroHailuo23FastRequest({
    required this.inputImages,
    required this.duration,
    this.prompt,
    this.promptOptimizer,
    this.resolution,
  }) : assert(
         duration == 6 || duration == 10,
         'duration must be 6 or 10 seconds',
       ),
       assert(
         duration != 10 || resolution != WiroHailuo23FastResolution.r1080p,
         '10-second videos are only available at 768P',
       );

  /// First-frame image URLs; the output video keeps this aspect ratio.
  final List<WiroFileInput> inputImages;

  /// Video duration in seconds; 6 or 10 (10 requires 768P).
  final int duration;

  /// Optional text prompt for the video.
  final String? prompt;

  /// Optional automatic prompt optimization; set `false` for stricter
  /// prompt adherence.
  final bool? promptOptimizer;

  /// Optional resolution. 1080P only produces 6-second videos.
  final WiroHailuo23FastResolution? resolution;

  @override
  WiroModelId get model => WiroModelId('minimax', 'hailuo-2-3-fast');

  @override
  WiroJson toJson() {
    return {
      'inputImage': inputImages.map((file) => file.wireValue).toList(),
      'duration': '$duration',
      'prompt': ?prompt,
      'promptOptimizer': promptOptimizer == null ? null : '$promptOptimizer',
      'resolution': ?resolution?.apiValue,
    }..removeWhere((key, value) => value == null);
  }
}
