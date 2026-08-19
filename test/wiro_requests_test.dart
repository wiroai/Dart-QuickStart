import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:wiro_client/wiro_client.dart';

void main() {
  group('WiroFlux2ProRequest', () {
    test('targets the Flux 2 Pro model', () {
      const request = WiroFlux2ProRequest(prompt: 'A mountain');

      expect(request.model.value, 'black-forest-labs/flux-2-pro');
    });

    test('serializes every typed parameter', () {
      final request = WiroFlux2ProRequest(
        prompt: 'A mountain',
        inputImages: [
          WiroFileInput.url(Uri.parse('https://example.com/input.png')),
        ],
        width: 1024,
        height: 768,
        safetyTolerance: 2,
        seed: 42,
        outputFormat: WiroFlux2ProOutputFormat.png,
      );

      expect(request.toJson(), {
        'prompt': 'A mountain',
        'inputImage': ['https://example.com/input.png'],
        'width': 1024,
        'height': 768,
        'safetyTolerance': 2,
        'seed': 42,
        'outputFormat': 'png',
      });
    });

    test('omits unset optional parameters', () {
      const request = WiroFlux2ProRequest(prompt: 'A mountain');

      expect(request.toJson(), {'prompt': 'A mountain'});
    });

    test('asserts schema constraints', () {
      expect(
        () => WiroFlux2ProRequest(prompt: ''),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => WiroFlux2ProRequest(prompt: 'A mountain', width: 100),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => WiroFlux2ProRequest(prompt: 'A mountain', height: 4096),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => WiroFlux2ProRequest(prompt: 'A mountain', safetyTolerance: 6),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => WiroFlux2ProRequest(prompt: 'A mountain', seed: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('allows zero dimensions to match the input image', () {
      const request = WiroFlux2ProRequest(
        prompt: 'A mountain',
        width: 0,
        height: 0,
      );

      expect(request.toJson()['width'], 0);
      expect(request.toJson()['height'], 0);
    });
  });

  group('WiroRunwayGen45Request', () {
    test('targets the Runway Gen-4.5 model', () {
      const request = WiroRunwayGen45Request(
        prompt: 'A drone shot',
        ratio: WiroRunwayGen45Ratio.auto,
        duration: 2,
      );

      expect(request.model.value, 'runway/gen-4-5');
    });

    test('serializes every typed parameter', () {
      final request = WiroRunwayGen45Request(
        prompt: 'A drone shot',
        ratio: WiroRunwayGen45Ratio.landscape16x9,
        duration: 5,
        inputImages: [
          WiroFileInput.url(Uri.parse('https://example.com/frame.png')),
        ],
        contentModeration: WiroRunwayGen45Moderation.low,
        seed: 7,
      );

      expect(request.toJson(), {
        'prompt': 'A drone shot',
        'ratio': '16:9',
        'duration': 5,
        'inputImage': ['https://example.com/frame.png'],
        'contentModeration': 'low',
        'seed': 7,
      });
    });

    test('omits unset optional parameters', () {
      const request = WiroRunwayGen45Request(
        prompt: 'A drone shot',
        ratio: WiroRunwayGen45Ratio.ultrawide21x9,
        duration: 2,
      );

      expect(request.toJson(), {
        'prompt': 'A drone shot',
        'ratio': '21:9',
        'duration': 2,
      });
    });

    test('asserts schema constraints', () {
      expect(
        () => WiroRunwayGen45Request(
          prompt: '',
          ratio: WiroRunwayGen45Ratio.auto,
          duration: 2,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => WiroRunwayGen45Request(
          prompt: 'p' * 1001,
          ratio: WiroRunwayGen45Ratio.auto,
          duration: 2,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => WiroRunwayGen45Request(
          prompt: 'A drone shot',
          ratio: WiroRunwayGen45Ratio.auto,
          duration: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => WiroRunwayGen45Request(
          prompt: 'A drone shot',
          ratio: WiroRunwayGen45Ratio.auto,
          duration: 2,
          seed: 4294967296,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WiroGptImage2Request', () {
    test('serializes every typed parameter', () {
      final request = WiroGptImage2Request(
        prompt: 'A mug',
        resolution: WiroGptImage2Resolution.r1k,
        ratio: WiroGptImage2Ratio.square,
        quality: WiroGptImage2Quality.low,
        samples: 2,
        inputImages: [
          WiroFileInput.url(Uri.parse('https://example.com/in.png')),
        ],
        inputImageMasks: [
          WiroFileInput.url(Uri.parse('https://example.com/mask.png')),
        ],
        background: WiroGptImage2Background.opaque,
        outputFormat: WiroGptImage2OutputFormat.webp,
        outputCompression: 80,
        moderation: WiroGptImage2Moderation.low,
      );

      expect(request.model.value, 'openai/gpt-image-2');
      expect(request.toJson(), {
        'prompt': 'A mug',
        'resolution': '1k',
        'ratio': '1:1',
        'quality': 'low',
        'samples': 2,
        'inputImage': ['https://example.com/in.png'],
        'inputImageMask': ['https://example.com/mask.png'],
        'background': 'opaque',
        'outputFormat': 'webp',
        'outputCompression': 80,
        'moderation': 'low',
      });
    });

    test('omits unset optional parameters and asserts bounds', () {
      const request = WiroGptImage2Request(
        prompt: 'A mug',
        resolution: WiroGptImage2Resolution.r4k,
        ratio: WiroGptImage2Ratio.landscape16x9,
        quality: WiroGptImage2Quality.high,
        samples: 1,
      );

      expect(request.toJson(), {
        'prompt': 'A mug',
        'resolution': '4k',
        'ratio': '16:9',
        'quality': 'high',
        'samples': 1,
      });
      expect(
        () => WiroGptImage2Request(
          prompt: 'A mug',
          resolution: WiroGptImage2Resolution.r1k,
          ratio: WiroGptImage2Ratio.square,
          quality: WiroGptImage2Quality.low,
          samples: 11,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WiroNanoBananaProRequest', () {
    test('serializes typed parameters', () {
      final request = WiroNanoBananaProRequest(
        prompt: 'A fox',
        inputImages: [
          WiroFileInput.url(Uri.parse('https://example.com/ref.png')),
        ],
        aspectRatio: WiroNanoBananaProRatio.ultrawide21x9,
        resolution: WiroNanoBananaProResolution.r2k,
        safetySetting: WiroNanoBananaProSafetySetting.blockOnlyHigh,
      );

      expect(request.model.value, 'google/nano-banana-pro');
      expect(request.toJson(), {
        'prompt': 'A fox',
        'inputImage': ['https://example.com/ref.png'],
        'aspectRatio': '21:9',
        'resolution': '2K',
        'safetySetting': 'BLOCK_ONLY_HIGH',
      });
    });
  });

  group('WiroSeedreamV4Request', () {
    test('serializes typed parameters with string booleans', () {
      const request = WiroSeedreamV4Request(
        prompt: 'One poster',
        size: WiroSeedreamV4Size.panorama3024x1296,
        maxImages: 1,
        watermark: false,
      );

      expect(request.model.value, 'bytedance/seedream-v4');
      expect(request.toJson(), {
        'prompt': 'One poster',
        'size': '3024x1296',
        'maxImages': 1,
        'watermark': 'false',
      });
    });
  });

  group('WiroGrokImagineImageRequest', () {
    test('serializes typed parameters', () {
      const request = WiroGrokImagineImageRequest(
        prompt: 'A neon alley',
        samples: 3,
        resolution: WiroGrokImagineImageResolution.r2k,
        aspectRatio: WiroGrokImagineImageRatio.landscape19_5x9,
      );

      expect(request.model.value, 'xai/grok-imagine-image');
      expect(request.toJson(), {
        'prompt': 'A neon alley',
        'samples': 3,
        'resolution': '2k',
        'aspectRatio': '19.5:9',
      });
    });
  });

  group('WiroSeedance20Request', () {
    test('serializes select values as strings', () {
      const request = WiroSeedance20Request(
        prompt: 'A time-lapse',
        resolution: WiroSeedance20Resolution.r480p,
        ratio: WiroSeedance20Ratio.adaptive,
        duration: 4,
        generateAudio: false,
        promptEnhancement: true,
        watermark: false,
        seed: 0,
      );

      expect(request.model.value, 'bytedance/seedance-2-0');
      expect(request.toJson(), {
        'prompt': 'A time-lapse',
        'resolution': '480p',
        'ratio': 'adaptive',
        'duration': '4',
        'generateAudio': 'false',
        'promptEnhancement': 'true',
        'watermark': 'false',
        'seed': 0,
      });
    });

    test('asserts duration bounds', () {
      expect(
        () => WiroSeedance20Request(
          resolution: WiroSeedance20Resolution.r480p,
          ratio: WiroSeedance20Ratio.adaptive,
          duration: 16,
          generateAudio: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WiroKlingV3Request', () {
    test('serializes sound as on/off', () {
      const request = WiroKlingV3Request(
        prompt: 'A paper boat',
        mode: WiroKlingV3Mode.ultra4k,
        duration: 10,
        ratio: WiroKlingV3Ratio.portrait9x16,
        sound: true,
      );

      expect(request.model.value, 'klingai/kling-v3');
      expect(request.toJson(), {
        'mode': '4k',
        'duration': '10',
        'ratio': '9:16',
        'sound': 'on',
        'prompt': 'A paper boat',
        'multiPrompt': '',
      });
    });

    test('requires multiPrompt for customize shots', () {
      expect(
        () => WiroKlingV3Request(
          mode: WiroKlingV3Mode.std,
          duration: 5,
          ratio: WiroKlingV3Ratio.square,
          sound: false,
          multiShot: true,
          shotType: WiroKlingV3ShotType.customize,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WiroVeo31Request', () {
    test('serializes typed parameters', () {
      final request = WiroVeo31Request(
        prompt: 'A balloon over vineyards',
        durationSeconds: 8,
        referenceImages: [
          WiroFileInput.url(Uri.parse('https://example.com/ref.png')),
        ],
        aspectRatio: WiroVeo31Ratio.matchInputImage,
        resolution: WiroVeo31Resolution.r1080p,
        negativePrompt: 'clouds',
        seed: 7,
      );

      expect(request.model.value, 'google/veo3-1');
      expect(request.toJson(), {
        'durationSeconds': '8',
        'prompt': 'A balloon over vineyards',
        'inputImage3': ['https://example.com/ref.png'],
        'aspectRatio': 'match_input_image',
        'resolution': '1080p',
        'negativePrompt': 'clouds',
        'seed': 7,
      });
    });

    test('asserts allowed durations', () {
      expect(
        () => WiroVeo31Request(durationSeconds: 5),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WiroSora2ProRequest', () {
    test('serializes typed parameters', () {
      const request = WiroSora2ProRequest(
        prompt: 'A whale breaching',
        seconds: 12,
        resolution: WiroSora2ProResolution.r1024p,
        ratio: WiroSora2ProRatio.auto,
      );

      expect(request.model.value, 'openai/sora-2-pro');
      expect(request.toJson(), {
        'prompt': 'A whale breaching',
        'seconds': '12',
        'resolution': '1024p',
        'ratio': 'auto',
      });
    });
  });

  group('WiroHailuo23FastRequest', () {
    test('serializes typed parameters', () {
      final request = WiroHailuo23FastRequest(
        inputImages: [
          WiroFileInput.url(Uri.parse('https://example.com/frame.png')),
        ],
        duration: 6,
        prompt: 'Slow pan',
        promptOptimizer: false,
        resolution: WiroHailuo23FastResolution.r1080p,
      );

      expect(request.model.value, 'minimax/hailuo-2-3-fast');
      expect(request.toJson(), {
        'inputImage': ['https://example.com/frame.png'],
        'duration': '6',
        'prompt': 'Slow pan',
        'promptOptimizer': 'false',
        'resolution': '1080P',
      });
    });

    test('rejects 10-second videos at 1080P', () {
      expect(
        () => WiroHailuo23FastRequest(
          inputImages: [
            WiroFileInput.url(Uri.parse('https://example.com/frame.png')),
          ],
          duration: 10,
          resolution: WiroHailuo23FastResolution.r1080p,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WiroGrokImagineVideoRequest', () {
    test('serializes typed parameters', () {
      const request = WiroGrokImagineVideoRequest(
        prompt: 'A drone shot',
        duration: 5,
        aspectRatio: WiroGrokImagineVideoRatio.auto,
        resolution: WiroGrokImagineVideoResolution.r480p,
      );

      expect(request.model.value, 'xai/grok-imagine-video');
      expect(request.toJson(), {
        'prompt': 'A drone shot',
        'duration': '5',
        'aspectRatio': 'auto',
        'resolution': '480p',
      });
    });
  });

  group('WiroLyria3Request', () {
    test('serializes typed parameters', () {
      const request = WiroLyria3Request(prompt: 'Lo-fi hip hop, 72 BPM');

      expect(request.model.value, 'google/lyria-3');
      expect(request.toJson(), {'prompt': 'Lo-fi hip hop, 72 BPM'});
    });
  });

  group('WiroDynamicRequest', () {
    test('wraps any model with a dynamic parameter map', () {
      final request = Wiro.model(
        'acme/brand-new-model',
        parameters: {'prompt': 'A poster', 'samples': 2},
      );

      expect(request.model.value, 'acme/brand-new-model');
      expect(request.toJson(), {'prompt': 'A poster', 'samples': 2});
    });

    test('rejects an invalid model slug', () {
      expect(
        () => Wiro.model('not-a-slug', parameters: {}),
        throwsArgumentError,
      );
    });

    test('keeps file inputs for client-side resolution', () {
      final request = Wiro.model(
        'acme/brand-new-model',
        parameters: {
          'inputImage': [
            WiroFileInput.url(Uri.parse('https://example.com/a.png')),
          ],
        },
      );

      expect(request.toJson()['inputImage'], [isA<WiroUrlInput>()]);
    });
  });

  group('Wiro', () {
    test('every factory targets its model', () {
      final requests = <WiroModelRequest>[
        Wiro.flux2Pro(prompt: 'p'),
        Wiro.gptImage2(
          prompt: 'p',
          resolution: WiroGptImage2Resolution.r1k,
          ratio: WiroGptImage2Ratio.square,
          quality: WiroGptImage2Quality.low,
          samples: 1,
        ),
        Wiro.nanoBananaPro(prompt: 'p'),
        Wiro.seedreamV4(
          prompt: 'p',
          size: WiroSeedreamV4Size.square2048,
          maxImages: 1,
          watermark: false,
        ),
        Wiro.grokImagineImage(
          prompt: 'p',
          samples: 1,
          resolution: WiroGrokImagineImageResolution.r1k,
        ),
        Wiro.runwayGen45(
          prompt: 'p',
          ratio: WiroRunwayGen45Ratio.auto,
          duration: 2,
        ),
        Wiro.seedance20(
          resolution: WiroSeedance20Resolution.r480p,
          ratio: WiroSeedance20Ratio.adaptive,
          duration: 4,
          generateAudio: false,
        ),
        Wiro.klingV3(
          mode: WiroKlingV3Mode.std,
          duration: 5,
          ratio: WiroKlingV3Ratio.landscape16x9,
          sound: false,
        ),
        Wiro.veo31(durationSeconds: 4),
        Wiro.sora2Pro(prompt: 'p', seconds: 4),
        Wiro.hailuo23Fast(
          inputImages: [
            WiroFileInput.url(Uri.parse('https://example.com/f.png')),
          ],
          duration: 6,
        ),
        Wiro.grokImagineVideo(
          prompt: 'p',
          duration: 5,
          aspectRatio: WiroGrokImagineVideoRatio.auto,
          resolution: WiroGrokImagineVideoResolution.r480p,
        ),
        Wiro.lyria3(prompt: 'p'),
      ];

      expect(requests.map((request) => request.model.value), [
        'black-forest-labs/flux-2-pro',
        'openai/gpt-image-2',
        'google/nano-banana-pro',
        'bytedance/seedream-v4',
        'xai/grok-imagine-image',
        'runway/gen-4-5',
        'bytedance/seedance-2-0',
        'klingai/kling-v3',
        'google/veo3-1',
        'openai/sora-2-pro',
        'minimax/hailuo-2-3-fast',
        'xai/grok-imagine-video',
        'google/lyria-3',
      ]);
    });

    test('flux2Pro builds a full Flux 2 Pro request', () {
      final request = Wiro.flux2Pro(
        prompt: 'A mountain',
        inputImages: [
          WiroFileInput.url(Uri.parse('https://example.com/input.png')),
        ],
        width: 1024,
        height: 768,
        safetyTolerance: 2,
        seed: 42,
        outputFormat: WiroFlux2ProOutputFormat.png,
      );

      expect(request.model.value, 'black-forest-labs/flux-2-pro');
      expect(request.toJson(), {
        'prompt': 'A mountain',
        'inputImage': ['https://example.com/input.png'],
        'width': 1024,
        'height': 768,
        'safetyTolerance': 2,
        'seed': 42,
        'outputFormat': 'png',
      });
    });

    test('runwayGen45 builds a full Runway Gen-4.5 request', () {
      final request = Wiro.runwayGen45(
        prompt: 'A drone shot',
        ratio: WiroRunwayGen45Ratio.landscape16x9,
        duration: 5,
        inputImages: [
          WiroFileInput.url(Uri.parse('https://example.com/frame.png')),
        ],
        contentModeration: WiroRunwayGen45Moderation.low,
        seed: 7,
      );

      expect(request.model.value, 'runway/gen-4-5');
      expect(request.toJson(), {
        'prompt': 'A drone shot',
        'ratio': '16:9',
        'duration': 5,
        'inputImage': ['https://example.com/frame.png'],
        'contentModeration': 'low',
        'seed': 7,
      });
    });
  });

  group('WiroClient typed requests', () {
    test('runs a typed request against the request model path', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/Run/runway/gen-4-5');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['ratio'], '9:16');
          expect(body['duration'], 3);
          return _jsonResponse(_runResponse);
        }),
      );

      final result = await client.runRequest(
        const WiroRunwayGen45Request(
          prompt: 'A drone shot',
          ratio: WiroRunwayGen45Ratio.portrait9x16,
          duration: 3,
        ),
      );

      expect(result.taskToken?.value, 'task-token');
    });

    test('subscribes with a typed request until completion', () async {
      final client = WiroClient(
        apiKey: 'test-key',
        pollInterval: Duration.zero,
        httpClient: MockClient((request) async {
          if (request.url.path.startsWith('/v1/Run')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['prompt'], 'A mountain');
            expect(body['outputFormat'], 'jpeg');
            return _jsonResponse(_runResponse);
          }
          return _jsonResponse(_completedTaskResponse);
        }),
      );

      final result = await client.subscribeRequest(
        const WiroFlux2ProRequest(
          prompt: 'A mountain',
          outputFormat: WiroFlux2ProOutputFormat.jpeg,
        ),
      );

      expect(result, isA<WiroTaskSuccess>());
    });
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

const Map<String, Object?> _runResponse = {
  'result': true,
  'taskid': '42',
  'socketaccesstoken': 'task-token',
};

const Map<String, Object?> _completedTaskResponse = {
  'result': true,
  'tasklist': [
    {
      'id': '42',
      'socketaccesstoken': 'task-token',
      'status': 'task_postprocess_end',
      'pexit': '0',
    },
  ],
};
