import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/request/wiro_dynamic_request.dart';
import 'package:wiro_client/src/request/wiro_flux_2_pro_request.dart';
import 'package:wiro_client/src/request/wiro_gpt_image_2_request.dart';
import 'package:wiro_client/src/request/wiro_grok_imagine_image_request.dart';
import 'package:wiro_client/src/request/wiro_grok_imagine_video_request.dart';
import 'package:wiro_client/src/request/wiro_hailuo_2_3_fast_request.dart';
import 'package:wiro_client/src/request/wiro_kling_v3_request.dart';
import 'package:wiro_client/src/request/wiro_lyria_3_request.dart';
import 'package:wiro_client/src/request/wiro_nano_banana_pro_request.dart';
import 'package:wiro_client/src/request/wiro_runway_gen_4_5_request.dart';
import 'package:wiro_client/src/request/wiro_seedance_2_0_request.dart';
import 'package:wiro_client/src/request/wiro_seedream_v4_request.dart';
import 'package:wiro_client/src/request/wiro_sora_2_pro_request.dart';
import 'package:wiro_client/src/request/wiro_upscaler_request.dart';
import 'package:wiro_client/src/request/wiro_veo_3_1_request.dart';

/// Discoverable entry point for every model request in the SDK.
///
/// Type `Wiro.` in your IDE to list all models with typed parameters.
/// Each factory mirrors the model's schema, so required parameters,
/// value ranges, and select options are checked at compile time:
///
/// ```dart
/// final result = await client.subscribeRequest(
///   Wiro.flux2Pro(prompt: 'A cinematic mountain lake'),
/// );
/// ```
///
/// Any other model runs through [Wiro.model] with a parameter map:
///
/// ```dart
/// final result = await client.subscribeRequest(
///   Wiro.model('owner/model', parameters: {'prompt': '...'}),
/// );
/// ```
abstract final class Wiro {
  /// Runs any Wiro model with dynamic [parameters].
  ///
  /// Use this when the SDK has no typed factory for the model. [slug]
  /// is the `owner/model` identifier shown on the model's Wiro page,
  /// for example `xai/grok-imagine-video`. The [parameters] map travels
  /// as-is; `WiroFileInput` values inside it are still uploaded
  /// automatically.
  ///
  /// Call `WiroClient.getModelSchema` to discover the parameters a
  /// model accepts, and `WiroModelSchema.validate` to check the map
  /// locally before a paid run starts.
  static WiroDynamicRequest model(
    String slug, {
    required WiroJson parameters,
  }) {
    return WiroDynamicRequest(WiroModelId.parse(slug), parameters: parameters);
  }

  // ---------------------------------------------------------------
  // Image generation and editing
  // ---------------------------------------------------------------

  /// Generates images with `black-forest-labs/flux-2-pro`.
  ///
  /// Only [prompt] is required; every other parameter falls back to the
  /// model's server-side default when omitted.
  ///
  /// - [prompt]: text describing the image. Cannot be empty.
  /// - [inputImages]: input image URLs for image-to-image and editing runs.
  /// - [width] and [height]: pixels; a multiple of 16 between 64 and 2048,
  ///   or `0` to match the input image.
  /// - [safetyTolerance]: moderation tolerance from 0 (most strict) to
  ///   5 (least strict).
  /// - [seed]: fixed seed for reproducible results.
  /// - [outputFormat]: JPEG or PNG output.
  static WiroFlux2ProRequest flux2Pro({
    required String prompt,
    List<WiroFileInput>? inputImages,
    int? width,
    int? height,
    int? safetyTolerance,
    int? seed,
    WiroFlux2ProOutputFormat? outputFormat,
  }) {
    return WiroFlux2ProRequest(
      prompt: prompt,
      inputImages: inputImages,
      width: width,
      height: height,
      safetyTolerance: safetyTolerance,
      seed: seed,
      outputFormat: outputFormat,
    );
  }

  /// Generates or edits images with `openai/gpt-image-2`.
  ///
  /// - [prompt]: description of the image or edit; at most 32,000
  ///   characters.
  /// - [resolution]: 1K, 2K, or 4K output tier.
  /// - [ratio]: output aspect ratio.
  /// - [quality]: low, medium, or high.
  /// - [samples]: number of images to generate (1-10).
  /// - [inputImages]: images to edit, up to 16.
  /// - [inputImageMasks]: masks defining edit areas; requires input
  ///   images.
  /// - [background]: auto or opaque.
  /// - [outputFormat]: PNG (default), JPEG, or WebP.
  /// - [outputCompression]: 0-100 for JPEG/WebP; defaults to 100.
  /// - [moderation]: auto or low.
  static WiroGptImage2Request gptImage2({
    required String prompt,
    required WiroGptImage2Resolution resolution,
    required WiroGptImage2Ratio ratio,
    required WiroGptImage2Quality quality,
    required int samples,
    List<WiroFileInput>? inputImages,
    List<WiroFileInput>? inputImageMasks,
    WiroGptImage2Background? background,
    WiroGptImage2OutputFormat? outputFormat,
    int? outputCompression,
    WiroGptImage2Moderation? moderation,
  }) {
    return WiroGptImage2Request(
      prompt: prompt,
      resolution: resolution,
      ratio: ratio,
      quality: quality,
      samples: samples,
      inputImages: inputImages,
      inputImageMasks: inputImageMasks,
      background: background,
      outputFormat: outputFormat,
      outputCompression: outputCompression,
      moderation: moderation,
    );
  }

  /// Generates or edits images with `google/nano-banana-pro`.
  ///
  /// - [prompt]: text prompt. Cannot be empty.
  /// - [inputImages]: reference image URLs, up to 14.
  /// - [aspectRatio]: output aspect ratio.
  /// - [resolution]: 1K (default), 2K, or 4K.
  /// - [safetySetting]: safety filter threshold.
  static WiroNanoBananaProRequest nanoBananaPro({
    required String prompt,
    List<WiroFileInput>? inputImages,
    WiroNanoBananaProRatio? aspectRatio,
    WiroNanoBananaProResolution? resolution,
    WiroNanoBananaProSafetySetting? safetySetting,
  }) {
    return WiroNanoBananaProRequest(
      prompt: prompt,
      inputImages: inputImages,
      aspectRatio: aspectRatio,
      resolution: resolution,
      safetySetting: safetySetting,
    );
  }

  /// Generates or edits images with `bytedance/seedream-v4`.
  ///
  /// - [prompt]: text prompt; also state how many images you want.
  /// - [size]: output resolution preset.
  /// - [maxImages]: output cap (1-15, including input references).
  /// - [watermark]: whether outputs carry a watermark.
  /// - [inputImages]: images for creating, editing, or combining.
  static WiroSeedreamV4Request seedreamV4({
    required String prompt,
    required WiroSeedreamV4Size size,
    required int maxImages,
    required bool watermark,
    List<WiroFileInput>? inputImages,
  }) {
    return WiroSeedreamV4Request(
      prompt: prompt,
      size: size,
      maxImages: maxImages,
      watermark: watermark,
      inputImages: inputImages,
    );
  }

  /// Generates or edits images with `xai/grok-imagine-image`.
  ///
  /// - [prompt]: description of the image or edit. Cannot be empty.
  /// - [samples]: number of images to generate (1-10).
  /// - [resolution]: 1K or 2K output.
  /// - [inputImages]: source image for editing; at most one.
  /// - [aspectRatio]: ratio for text-to-image runs; edits keep the
  ///   input image's ratio.
  static WiroGrokImagineImageRequest grokImagineImage({
    required String prompt,
    required int samples,
    required WiroGrokImagineImageResolution resolution,
    List<WiroFileInput>? inputImages,
    WiroGrokImagineImageRatio? aspectRatio,
  }) {
    return WiroGrokImagineImageRequest(
      prompt: prompt,
      samples: samples,
      resolution: resolution,
      inputImages: inputImages,
      aspectRatio: aspectRatio,
    );
  }

  /// Upscales images with `google/upscaler` (Imagen Upscale).
  ///
  /// - [inputImage]: the image to upscale, as a hosted URL or device
  ///   bytes. The output resolution (input resolution × [upscaleFactor])
  ///   must not exceed 17 megapixels.
  /// - [upscaleFactor]: scaling factor, typically 2, 3, or 4.
  /// - [outputType]: PNG (default) or JPEG output.
  /// - [compressionQuality]: JPEG detail level (0-100, default 75);
  ///   only applies when [outputType] is JPEG.
  static WiroUpscalerRequest upscaler({
    required WiroFileInput inputImage,
    required int upscaleFactor,
    WiroUpscalerOutputType outputType = WiroUpscalerOutputType.png,
    int? compressionQuality,
  }) {
    return WiroUpscalerRequest(
      inputImage: [inputImage],
      upscaleFactor: upscaleFactor,
      outputType: outputType,
      compressionQuality: compressionQuality,
    );
  }

  // ---------------------------------------------------------------
  // Video generation
  // ---------------------------------------------------------------

  /// Generates videos with `runway/gen-4-5`.
  ///
  /// - [prompt]: video description; at most 1000 characters.
  /// - [ratio]: output aspect ratio; `auto` follows the input image.
  /// - [duration]: video length in seconds, 2 to 10 under current
  ///   pricing.
  /// - [inputImages]: first-frame image URLs for image-to-video runs.
  /// - [contentModeration]: public-figure moderation threshold.
  /// - [seed]: fixed seed (0 to 4294967295) for reproducible results.
  static WiroRunwayGen45Request runwayGen45({
    required String prompt,
    required WiroRunwayGen45Ratio ratio,
    required int duration,
    List<WiroFileInput>? inputImages,
    WiroRunwayGen45Moderation? contentModeration,
    int? seed,
  }) {
    return WiroRunwayGen45Request(
      prompt: prompt,
      ratio: ratio,
      duration: duration,
      inputImages: inputImages,
      contentModeration: contentModeration,
      seed: seed,
    );
  }

  /// Generates videos with `bytedance/seedance-2-0`.
  ///
  /// - [resolution]: 480p, 720p, 1080p, or 4K.
  /// - [ratio]: output aspect ratio; `adaptive` lets the model choose.
  /// - [duration]: 4 to 15 seconds.
  /// - [generateAudio]: whether the video includes synchronized audio.
  /// - [prompt]: text prompt for the video.
  /// - [inputImage]: first-frame image; [lastFrameImage] requires it.
  /// - [referenceImages]: 1-9 references, addressed as `[Image 1]` in
  ///   the prompt; [referenceAudios]: 1-3 wav/mp3 files.
  /// - [promptEnhancement]: AI prompt rewrite that reduces
  ///   content-filter failures.
  /// - [watermark]: watermark toggle; [seed]: 0 for random.
  static WiroSeedance20Request seedance20({
    required WiroSeedance20Resolution resolution,
    required WiroSeedance20Ratio ratio,
    required int duration,
    required bool generateAudio,
    String? prompt,
    List<WiroFileInput>? inputImage,
    List<WiroFileInput>? lastFrameImage,
    List<WiroFileInput>? referenceImages,
    List<WiroFileInput>? referenceAudios,
    bool? promptEnhancement,
    bool? watermark,
    int? seed,
  }) {
    return WiroSeedance20Request(
      resolution: resolution,
      ratio: ratio,
      duration: duration,
      generateAudio: generateAudio,
      prompt: prompt,
      inputImage: inputImage,
      lastFrameImage: lastFrameImage,
      referenceImages: referenceImages,
      referenceAudios: referenceAudios,
      promptEnhancement: promptEnhancement,
      watermark: watermark,
      seed: seed,
    );
  }

  /// Generates videos with `klingai/kling-v3`.
  ///
  /// - [mode]: std (720p), pro (1080p), or 4K.
  /// - [duration]: 5, 10, or 15 seconds.
  /// - [ratio]: aspect ratio; text-to-video only.
  /// - [sound]: audio toggle; forced off with a [lastFrameImage].
  /// - [prompt]: text prompt for the video.
  /// - [inputImage] and [lastFrameImage]: first and last frames.
  /// - [multiShot], [shotType], [multiPrompt]: multi-shot controls;
  ///   `customize` requires a [multiPrompt] JSON string.
  static WiroKlingV3Request klingV3({
    required WiroKlingV3Mode mode,
    required int duration,
    required WiroKlingV3Ratio ratio,
    required bool sound,
    String? prompt,
    List<WiroFileInput>? inputImage,
    List<WiroFileInput>? lastFrameImage,
    bool? multiShot,
    WiroKlingV3ShotType? shotType,
    String? multiPrompt,
  }) {
    return WiroKlingV3Request(
      mode: mode,
      duration: duration,
      ratio: ratio,
      sound: sound,
      prompt: prompt,
      inputImage: inputImage,
      lastFrameImage: lastFrameImage,
      multiShot: multiShot,
      shotType: shotType,
      multiPrompt: multiPrompt,
    );
  }

  /// Generates videos with `google/veo3-1`.
  ///
  /// - [durationSeconds]: 4, 6, or 8 seconds.
  /// - [prompt]: text prompt for the video.
  /// - [inputImage] and [lastFrameImage]: first and last frames.
  /// - [referenceImages]: 1-3 references; forces eight seconds and
  ///   ignores first/last frames.
  /// - [aspectRatio]: 16:9, 9:16, or match the input image.
  /// - [resolution]: 720p, 1080p, or 4K.
  /// - [negativePrompt]: content to discourage; [seed]: omit for
  ///   random results.
  static WiroVeo31Request veo31({
    required int durationSeconds,
    String? prompt,
    List<WiroFileInput>? inputImage,
    List<WiroFileInput>? lastFrameImage,
    List<WiroFileInput>? referenceImages,
    WiroVeo31Ratio? aspectRatio,
    WiroVeo31Resolution? resolution,
    String? negativePrompt,
    int? seed,
  }) {
    return WiroVeo31Request(
      durationSeconds: durationSeconds,
      prompt: prompt,
      inputImage: inputImage,
      lastFrameImage: lastFrameImage,
      referenceImages: referenceImages,
      aspectRatio: aspectRatio,
      resolution: resolution,
      negativePrompt: negativePrompt,
      seed: seed,
    );
  }

  /// Generates videos with `openai/sora-2-pro`.
  ///
  /// - [prompt]: text prompt for the video. Cannot be empty.
  /// - [seconds]: 4, 8, 12, 16, or 20 seconds.
  /// - [inputImages]: optional input image URLs.
  /// - [resolution]: 720p, 1024p, or 1080p.
  /// - [ratio]: 16:9, 9:16, or auto (follows the input image).
  static WiroSora2ProRequest sora2Pro({
    required String prompt,
    required int seconds,
    List<WiroFileInput>? inputImages,
    WiroSora2ProResolution? resolution,
    WiroSora2ProRatio? ratio,
  }) {
    return WiroSora2ProRequest(
      prompt: prompt,
      seconds: seconds,
      inputImages: inputImages,
      resolution: resolution,
      ratio: ratio,
    );
  }

  /// Generates image-to-video clips with `minimax/hailuo-2-3-fast`.
  ///
  /// - [inputImages]: first-frame image; the output keeps its aspect
  ///   ratio.
  /// - [duration]: 6 or 10 seconds; 10 requires 768P.
  /// - [prompt]: text prompt for the video.
  /// - [promptOptimizer]: set `false` for stricter prompt adherence.
  /// - [resolution]: 768P or 1080P (1080P is limited to 6 seconds).
  static WiroHailuo23FastRequest hailuo23Fast({
    required List<WiroFileInput> inputImages,
    required int duration,
    String? prompt,
    bool? promptOptimizer,
    WiroHailuo23FastResolution? resolution,
  }) {
    return WiroHailuo23FastRequest(
      inputImages: inputImages,
      duration: duration,
      prompt: prompt,
      promptOptimizer: promptOptimizer,
      resolution: resolution,
    );
  }

  /// Generates videos with `xai/grok-imagine-video`.
  ///
  /// - [prompt]: description of the video. Cannot be empty.
  /// - [duration]: 5, 10, or 15 seconds.
  /// - [aspectRatio]: `auto` follows the input image.
  /// - [resolution]: 480p or 720p.
  /// - [inputImages]: first-frame image; at most one.
  static WiroGrokImagineVideoRequest grokImagineVideo({
    required String prompt,
    required int duration,
    required WiroGrokImagineVideoRatio aspectRatio,
    required WiroGrokImagineVideoResolution resolution,
    List<WiroFileInput>? inputImages,
  }) {
    return WiroGrokImagineVideoRequest(
      prompt: prompt,
      duration: duration,
      aspectRatio: aspectRatio,
      resolution: resolution,
      inputImages: inputImages,
    );
  }

  // ---------------------------------------------------------------
  // Music generation
  // ---------------------------------------------------------------

  /// Generates a 30-second music track with `google/lyria-3`.
  ///
  /// - [prompt]: genre, instruments, mood, BPM, key; use
  ///   `[Verse]`/`[Chorus]` tags for lyrics or "Instrumental only,
  ///   no vocals" for instrumentals.
  /// - [inputImages]: optional source images to inspire the music.
  static WiroLyria3Request lyria3({
    required String prompt,
    List<WiroFileInput>? inputImages,
  }) {
    return WiroLyria3Request(
      prompt: prompt,
      inputImages: inputImages,
    );
  }
}
