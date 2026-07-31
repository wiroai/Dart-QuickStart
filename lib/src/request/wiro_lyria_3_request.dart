import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';

/// Typed request for the `google/lyria-3` music model.
///
/// Generates a 30-second, 48 kHz stereo track. Field constraints
/// mirror the model schema published by Wiro on 2026-07-24.
final class WiroLyria3Request implements WiroModelRequest {
  /// Creates a Lyria 3 music generation request.
  ///
  /// Only [prompt] is required. Describe genre, instruments, mood,
  /// BPM, and key; use `[Verse]`/`[Chorus]` tags for custom lyrics or
  /// add "Instrumental only, no vocals" for an instrumental track.
  ///
  /// ```dart
  /// const WiroLyria3Request(
  ///   prompt: 'Lo-fi hip hop, mellow piano, 72 BPM, rainy mood, '
  ///       'instrumental only, no vocals',
  /// );
  /// ```
  const WiroLyria3Request({required this.prompt, this.inputImages})
    : assert(prompt != '', 'prompt cannot be empty');

  /// Description of the 30-second clip: genre, instruments, mood,
  /// BPM, key, and optional `[Verse]`/`[Chorus]` lyric tags.
  final String prompt;

  /// Optional source image URLs to inspire the music (jpg, jpeg, png,
  /// webp).
  final List<WiroFileInput>? inputImages;

  @override
  WiroModelId get model => WiroModelId('google', 'lyria-3');

  @override
  WiroJson toJson() {
    return {
      'prompt': prompt,
      'inputImage': ?inputImages?.map((file) => file.wireValue).toList(),
    };
  }
}
