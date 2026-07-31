import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wiro_client/src/model/json_reader.dart';
import 'package:wiro_client/src/model/wiro_file_input.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model.dart';
import 'package:wiro_client/src/model/wiro_model_request.dart';
import 'package:wiro_client/src/model/wiro_result.dart';
import 'package:wiro_client/src/model/wiro_socket.dart';
import 'package:wiro_client/src/model/wiro_task.dart';
import 'package:wiro_client/src/model/wiro_task_update.dart';
import 'package:wiro_client/src/wiro_exception.dart';
import 'package:wiro_client/src/wiro_request.dart';

/// Authentication method used by [WiroClient].
enum WiroAuthType {
  /// Sends only the API key.
  apiKey,

  /// Signs every request with the API key and secret.
  signature,

  /// Sends no credentials; a backend proxy attaches them server-side.
  proxy,
}

/// Mock-friendly interface for the public Wiro client API.
abstract interface class WiroClientBase {
  /// Authentication method used by this client.
  WiroAuthType get authType;

  /// Delay between task status requests.
  Duration get pollInterval;

  /// Maximum duration of an individual HTTP request.
  Duration get requestTimeout;

  /// Retry behavior for safe read-like operations.
  WiroRetryPolicy get retryPolicy;

  /// Optional structured diagnostic event receiver.
  WiroLogger? get logger;

  /// Searches the models available on Wiro.
  Future<WiroPaginatedResult<WiroModel>> searchModels({
    String search = '',
    List<String> categories = const [],
    int start = 0,
    int limit = 20,
    WiroModelSort sort = WiroModelSort.relevance,
    String? owner,
    WiroSortOrder? order,
    WiroCancellationToken? cancellationToken,
  });

  /// Returns curated model categories.
  Future<List<WiroExploreCategory>> explore({
    WiroCancellationToken? cancellationToken,
  });

  /// Returns the input schema for [model].
  Future<WiroModelSchema> getModelSchema(
    WiroModelId model, {
    WiroCancellationToken? cancellationToken,
  });

  /// Starts [model] with the supplied dynamic [parameters].
  ///
  /// Any [WiroFileInput.bytes] value in [parameters] is uploaded
  /// automatically and replaced with its URL before the run starts.
  Future<WiroRunResult> runModel(
    WiroModelId model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    WiroCancellationToken? cancellationToken,
  });

  /// Starts a typed model [request] without tracking it.
  ///
  /// Build the [request] with a `Wiro` factory to get compile-time
  /// checked parameters; use [runModel] for models without a typed request.
  Future<WiroRunResult> runRequest(
    WiroModelRequest request, {
    Uri? callbackUrl,
    WiroCancellationToken? cancellationToken,
  });

  /// Starts [model], tracks it, and returns a typed terminal result.
  Future<WiroTaskResult> subscribe(
    WiroModelId model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
    WiroTaskTrackingMode trackingMode = WiroTaskTrackingMode.polling,
    WiroTaskUpdateCallback? onUpdate,
  });

  /// Starts a typed model [request], tracks it, and returns its result.
  ///
  /// Build the [request] with a `Wiro` factory to get compile-time
  /// checked parameters; use [subscribe] for models without a typed request.
  ///
  /// ```dart
  /// final result = await client.subscribeRequest(
  ///   Wiro.flux2Pro(prompt: 'A cinematic mountain lake'),
  /// );
  /// ```
  Future<WiroTaskResult> subscribeRequest(
    WiroModelRequest request, {
    Uri? callbackUrl,
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
    WiroTaskTrackingMode trackingMode = WiroTaskTrackingMode.polling,
    WiroTaskUpdateCallback? onUpdate,
  });

  /// Starts [model] and streams typed task updates.
  ///
  /// Cancelling the returned subscription stops active task tracking.
  Stream<WiroTaskUpdate> subscribeStream(
    WiroModelId model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
    WiroTaskTrackingMode trackingMode = WiroTaskTrackingMode.polling,
  });

  /// Returns task details using [token].
  Future<WiroTask> getTask(
    WiroTaskToken token, {
    WiroCancellationToken? cancellationToken,
  });

  /// Returns task details using the server-side task [id].
  Future<WiroTask> getTaskById(
    WiroTaskId id, {
    WiroCancellationToken? cancellationToken,
  });

  /// Requests cancellation of a queued task.
  Future<bool> cancelTask(
    WiroTaskToken taskToken, {
    WiroCancellationToken? cancellationToken,
  });

  /// Stops a running task.
  Future<bool> killTask(
    WiroTaskToken taskToken, {
    WiroCancellationToken? cancellationToken,
  });

  /// Uploads [bytes] to Wiro.
  Future<WiroUploadResult> uploadFile(
    List<int> bytes, {
    required String fileName,
    WiroCancellationToken? cancellationToken,
  });

  /// Uploads a byte [stream] to Wiro without buffering it in the SDK.
  Future<WiroUploadResult> uploadStream(
    Stream<List<int>> stream, {
    required int contentLength,
    required String fileName,
    WiroCancellationToken? cancellationToken,
  });

  /// Emits polled task snapshots until the task reaches a terminal status.
  Stream<WiroTask> watchTask(
    WiroTaskToken taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  });

  /// Streams realtime task events from Wiro over WebSocket.
  Stream<WiroSocketEvent> watchTaskSocket(
    WiroTaskToken taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  });

  /// Polls until a task reaches a terminal status.
  Future<WiroTask> waitForTask(
    WiroTaskToken taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  });

  /// Releases resources owned by this client.
  void close();
}

/// Client for the Wiro model and task APIs.
final class WiroClient implements WiroClientBase {
  /// Creates a Wiro API client.
  ///
  /// The supplied credentials must match the authentication type configured
  /// for the Wiro project. Use an HTTPS [baseUri] outside local development.
  WiroClient({
    required String apiKey,
    String? apiSecret,
    Uri? baseUri,
    Uri? socketUri,
    http.Client? httpClient,
    this.pollInterval = const Duration(seconds: 3),
    this.requestTimeout = const Duration(seconds: 30),
    this.retryPolicy = const WiroRetryPolicy(),
    this.logger,
  }) : _apiKey = apiKey,
       _apiSecret = apiSecret,
       _extraHeaders = const {},
       _baseUrl = _normalizeBaseUrl(
         _validateHttpOrigin(baseUri ?? defaultBaseUri, 'baseUri'),
       ),
       _socketUri = _validateSocketUri(socketUri ?? defaultSocketUri),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'Cannot be empty');
    }
    if (apiSecret != null && apiSecret.trim().isEmpty) {
      throw ArgumentError.value(apiSecret, 'apiSecret', 'Cannot be empty');
    }
    _validateTimings(requestTimeout, pollInterval);
  }

  /// Creates a client that routes requests through a backend proxy.
  ///
  /// The device never holds Wiro credentials. The proxy at [proxyUri] must
  /// accept the same REST paths as the Wiro API, attach the `x-api-key`
  /// header (and signature headers when required), and forward requests to
  /// Wiro. Use [headers] to authenticate the app's own users against the
  /// proxy, for example with an `Authorization` session header.
  ///
  /// Task WebSocket streams connect directly to [socketUri] because they
  /// authenticate with task tokens instead of API credentials.
  WiroClient.proxied({
    required Uri proxyUri,
    Map<String, String> headers = const {},
    Uri? socketUri,
    http.Client? httpClient,
    this.pollInterval = const Duration(seconds: 3),
    this.requestTimeout = const Duration(seconds: 30),
    this.retryPolicy = const WiroRetryPolicy(),
    this.logger,
  }) : _apiKey = null,
       _apiSecret = null,
       _extraHeaders = Map.unmodifiable(headers),
       _baseUrl = _normalizeBaseUrl(_validateHttpOrigin(proxyUri, 'proxyUri')),
       _socketUri = _validateSocketUri(socketUri ?? defaultSocketUri),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    _validateTimings(requestTimeout, pollInterval);
  }

  /// Default Wiro REST API endpoint.
  static final Uri defaultBaseUri = Uri.parse('https://api.wiro.ai/v1');

  /// Default Wiro task WebSocket endpoint.
  static final Uri defaultSocketUri = Uri.parse('wss://socket.wiro.ai/v1');

  final String? _apiKey;
  final String? _apiSecret;
  final Map<String, String> _extraHeaders;
  final String _baseUrl;
  final Uri _socketUri;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// Delay between task status requests.
  @override
  final Duration pollInterval;

  /// Maximum duration of an individual HTTP request.
  @override
  final Duration requestTimeout;

  /// Retry behavior for safe read-like HTTP operations.
  ///
  /// Model runs and file uploads are never retried automatically.
  @override
  final WiroRetryPolicy retryPolicy;

  /// Optional structured diagnostic event receiver.
  @override
  final WiroLogger? logger;

  /// Authentication method inferred from the configured credentials.
  @override
  WiroAuthType get authType {
    if (_apiKey == null) {
      return WiroAuthType.proxy;
    }
    return _apiSecret == null ? WiroAuthType.apiKey : WiroAuthType.signature;
  }

  /// Searches the models available on Wiro.
  @override
  Future<WiroPaginatedResult<WiroModel>> searchModels({
    String search = '',
    List<String> categories = const [],
    int start = 0,
    int limit = 20,
    WiroModelSort sort = WiroModelSort.relevance,
    String? owner,
    WiroSortOrder? order,
    WiroCancellationToken? cancellationToken,
  }) {
    if (start < 0) {
      throw ArgumentError.value(start, 'start', 'Cannot be negative');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 100');
    }

    return _post(
      '/Tool/List',
      {
        'start': '$start',
        'limit': '$limit',
        'search': search,
        'categories': categories,
        'sort': sort.apiValue,
        'hideworkflows': true,
        'summary': true,
        'slugowner': ?owner,
        'order': ?order?.apiValue,
      },
      (json) {
        return WiroPaginatedResult.fromJson(
          json,
          itemsKey: 'tool',
          itemFromJson: WiroModel.fromJson,
        );
      },
      cancellationToken: cancellationToken,
    );
  }

  /// Returns curated model categories.
  @override
  Future<List<WiroExploreCategory>> explore({
    WiroCancellationToken? cancellationToken,
  }) {
    return _post('/Tool/Explore', const {}, (json) {
      final categories = JsonReader.list(json['explore'])
          .map(JsonReader.map)
          .where((item) => item.isNotEmpty)
          .map(WiroExploreCategory.fromJson);
      return List.unmodifiable(categories);
    }, cancellationToken: cancellationToken);
  }

  /// Returns the input schema for [model].
  @override
  Future<WiroModelSchema> getModelSchema(
    WiroModelId model, {
    WiroCancellationToken? cancellationToken,
  }) {
    return _post(
      '/Tool/Detail',
      {'slugowner': model.owner, 'slugproject': model.project},
      _modelSchemaFromResponse,
      cancellationToken: cancellationToken,
    );
  }

  /// Starts [model] with the supplied dynamic [parameters].
  ///
  /// Any [WiroFileInput.bytes] value in [parameters] is uploaded
  /// automatically and replaced with its URL before the run starts.
  ///
  /// When [callbackUrl] is supplied, Wiro sends the completed task to that
  /// webhook URL.
  ///
  /// This billable operation is not retried automatically.
  @override
  Future<WiroRunResult> runModel(
    WiroModelId model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    WiroCancellationToken? cancellationToken,
  }) async {
    final callback = callbackUrl == null
        ? null
        : _validateCallbackUrl(callbackUrl);
    final resolved = await _resolveFileInputs(parameters, cancellationToken);
    return _post(
      '/Run/${Uri.encodeComponent(model.owner)}/'
      '${Uri.encodeComponent(model.project)}',
      {...resolved, if (callback != null) 'callbackUrl': callback.toString()},
      WiroRunResult.fromJson,
      cancellationToken: cancellationToken,
      retryable: false,
    );
  }

  /// Uploads device-local file inputs and replaces every [WiroFileInput]
  /// in [parameters] with its URL string.
  Future<WiroJson> _resolveFileInputs(
    WiroJson parameters,
    WiroCancellationToken? cancellationToken,
  ) async {
    if (!_containsFileInput(parameters)) {
      return parameters;
    }
    final resolved = await _resolveFileValue(parameters, cancellationToken);
    return (resolved! as Map<Object?, Object?>).cast<String, Object?>();
  }

  static bool _containsFileInput(Object? value) {
    return switch (value) {
      WiroFileInput() => true,
      final List<Object?> list => list.any(_containsFileInput),
      final Map<Object?, Object?> map => map.values.any(_containsFileInput),
      _ => false,
    };
  }

  Future<Object?> _resolveFileValue(
    Object? value,
    WiroCancellationToken? cancellationToken,
  ) async {
    switch (value) {
      case WiroUrlInput(:final url):
        return url.toString();
      case WiroBytesInput(:final bytes, :final fileName):
        final upload = await uploadFile(
          bytes,
          fileName: fileName,
          cancellationToken: cancellationToken,
        );
        final url = upload.files.isEmpty ? null : upload.files.first.url;
        if (url == null) {
          throw WiroUnknownApiException(
            'The upload for "$fileName" did not return a file URL.',
            statusCode: 200,
            responseBody: jsonEncode(upload.raw),
          );
        }
        return url.toString();
      case final List<Object?> list:
        return [
          for (final item in list)
            await _resolveFileValue(item, cancellationToken),
        ];
      case final Map<Object?, Object?> map:
        return {
          for (final entry in map.entries)
            entry.key: await _resolveFileValue(entry.value, cancellationToken),
        };
      case _:
        return value;
    }
  }

  /// Starts a typed model [request] without tracking it.
  ///
  /// This billable operation is not retried automatically.
  @override
  Future<WiroRunResult> runRequest(
    WiroModelRequest request, {
    Uri? callbackUrl,
    WiroCancellationToken? cancellationToken,
  }) {
    return runModel(
      request.model,
      parameters: request.toJson(),
      callbackUrl: callbackUrl,
      cancellationToken: cancellationToken,
    );
  }

  /// Starts [model], tracks it, and returns a typed terminal result.
  ///
  /// [trackingMode] chooses polling or WebSocket tracking. [onUpdate] receives
  /// the same sealed update type for both transports.
  @override
  Future<WiroTaskResult> subscribe(
    WiroModelId model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
    WiroTaskTrackingMode trackingMode = WiroTaskTrackingMode.polling,
    WiroTaskUpdateCallback? onUpdate,
  }) async {
    final task = await _subscribeTask(
      model,
      parameters: parameters,
      callbackUrl: callbackUrl,
      timeout: timeout,
      cancellationToken: cancellationToken,
      trackingMode: trackingMode,
      onUpdate: onUpdate,
    );
    return task.isSuccessful
        ? WiroTaskSuccess(task)
        : WiroTaskFailure.fromTask(task);
  }

  /// Starts a typed model [request], tracks it, and returns its result.
  @override
  Future<WiroTaskResult> subscribeRequest(
    WiroModelRequest request, {
    Uri? callbackUrl,
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
    WiroTaskTrackingMode trackingMode = WiroTaskTrackingMode.polling,
    WiroTaskUpdateCallback? onUpdate,
  }) {
    return subscribe(
      request.model,
      parameters: request.toJson(),
      callbackUrl: callbackUrl,
      timeout: timeout,
      cancellationToken: cancellationToken,
      trackingMode: trackingMode,
      onUpdate: onUpdate,
    );
  }

  /// Starts [model] and streams typed updates until tracking completes.
  ///
  /// Cancelling the returned subscription stops active task tracking.
  @override
  Stream<WiroTaskUpdate> subscribeStream(
    WiroModelId model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
    WiroTaskTrackingMode trackingMode = WiroTaskTrackingMode.polling,
  }) {
    final subscriptionToken = WiroCancellationToken();
    var cancelledByListener = false;
    if (cancellationToken case final callerToken?) {
      if (callerToken.isCancelled) {
        subscriptionToken.cancel();
      } else {
        unawaited(
          callerToken.whenCancelled.then((_) => subscriptionToken.cancel()),
        );
      }
    }

    late final StreamController<WiroTaskUpdate> controller;
    Future<void> track() async {
      try {
        await _subscribeTask(
          model,
          parameters: parameters,
          callbackUrl: callbackUrl,
          timeout: timeout,
          cancellationToken: subscriptionToken,
          trackingMode: trackingMode,
          onUpdate: (update) {
            if (!cancelledByListener && !controller.isClosed) {
              controller.add(update);
            }
          },
        );
      } on Object catch (error, stackTrace) {
        if (!cancelledByListener && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }

    controller = StreamController<WiroTaskUpdate>(
      onListen: () {
        unawaited(track());
      },
      onCancel: () {
        cancelledByListener = true;
        subscriptionToken.cancel();
      },
    );
    return controller.stream;
  }

  Future<WiroTask> _subscribeTask(
    WiroModelId model, {
    required WiroJson parameters,
    required Uri? callbackUrl,
    required Duration timeout,
    required WiroCancellationToken? cancellationToken,
    required WiroTaskTrackingMode trackingMode,
    required WiroTaskUpdateCallback? onUpdate,
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Must be greater than zero',
      );
    }

    final run = await runModel(
      model,
      parameters: parameters,
      callbackUrl: callbackUrl,
      cancellationToken: cancellationToken,
    );
    final taskToken = run.taskToken;
    if (taskToken == null) {
      throw WiroUnknownApiException(
        'The model run response did not contain a task token.',
        statusCode: 200,
        responseBody: jsonEncode(run.raw),
      );
    }

    final task = switch (trackingMode) {
      WiroTaskTrackingMode.polling => await _trackTaskWithPolling(
        taskToken,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onUpdate: onUpdate,
      ),
      WiroTaskTrackingMode.webSocket => await _trackTaskWithSocket(
        taskToken,
        timeout: timeout,
        cancellationToken: cancellationToken,
        onUpdate: onUpdate,
      ),
    };

    return task;
  }

  Future<WiroTask> _trackTaskWithPolling(
    WiroTaskToken taskToken, {
    required Duration timeout,
    WiroCancellationToken? cancellationToken,
    WiroTaskUpdateCallback? onUpdate,
  }) async {
    await for (final task in watchTask(
      taskToken,
      timeout: timeout,
      cancellationToken: cancellationToken,
    )) {
      onUpdate?.call(WiroTaskUpdate.fromTask(task));
      if (task.status.isTerminal) {
        return task;
      }
    }

    throw WiroTimeoutException(
      'Task did not finish within ${timeout.inSeconds} seconds.',
      timeout: timeout,
    );
  }

  Future<WiroTask> _trackTaskWithSocket(
    WiroTaskToken taskToken, {
    required Duration timeout,
    WiroCancellationToken? cancellationToken,
    WiroTaskUpdateCallback? onUpdate,
  }) async {
    final deadline = DateTime.now().add(timeout);
    await for (final event in watchTaskSocket(
      taskToken,
      timeout: timeout,
      cancellationToken: cancellationToken,
    )) {
      onUpdate?.call(WiroTaskUpdate.fromSocketEvent(event));
    }

    final task = await getTask(taskToken, cancellationToken: cancellationToken);
    if (task.status.isTerminal) {
      return task;
    }

    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw WiroTimeoutException(
        'Task did not finish within ${timeout.inSeconds} seconds.',
        timeout: timeout,
      );
    }
    return _trackTaskWithPolling(
      taskToken,
      timeout: remaining,
      cancellationToken: cancellationToken,
      onUpdate: onUpdate,
    );
  }

  /// Returns task details using [token].
  @override
  Future<WiroTask> getTask(
    WiroTaskToken token, {
    WiroCancellationToken? cancellationToken,
  }) {
    return _post(
      '/Task/Detail',
      {'tasktoken': token.value},
      _taskFromResponse,
      cancellationToken: cancellationToken,
    );
  }

  /// Returns task details using the server-side task [id].
  @override
  Future<WiroTask> getTaskById(
    WiroTaskId id, {
    WiroCancellationToken? cancellationToken,
  }) {
    return _post(
      '/Task/Detail',
      {'taskid': id.value},
      _taskFromResponse,
      cancellationToken: cancellationToken,
    );
  }

  /// Requests cancellation of a queued task.
  @override
  Future<bool> cancelTask(
    WiroTaskToken taskToken, {
    WiroCancellationToken? cancellationToken,
  }) {
    return _post(
      '/Task/Cancel',
      {'tasktoken': taskToken.value},
      (json) => JsonReader.boolean(json['result']),
      cancellationToken: cancellationToken,
    );
  }

  /// Stops a running task.
  @override
  Future<bool> killTask(
    WiroTaskToken taskToken, {
    WiroCancellationToken? cancellationToken,
  }) {
    return _post(
      '/Task/Kill',
      {'tasktoken': taskToken.value},
      (json) => JsonReader.boolean(json['result']),
      cancellationToken: cancellationToken,
    );
  }

  /// Uploads [bytes] to Wiro.
  @override
  Future<WiroUploadResult> uploadFile(
    List<int> bytes, {
    required String fileName,
    WiroCancellationToken? cancellationToken,
  }) {
    return uploadStream(
      Stream.value(bytes),
      contentLength: bytes.length,
      fileName: fileName,
      cancellationToken: cancellationToken,
    );
  }

  /// Uploads a byte [stream] to Wiro without buffering it in the SDK.
  ///
  /// The caller must provide the exact [contentLength]. Uploads are not
  /// automatically retried because a retry could create a duplicate file.
  @override
  Future<WiroUploadResult> uploadStream(
    Stream<List<int>> stream, {
    required int contentLength,
    required String fileName,
    WiroCancellationToken? cancellationToken,
  }) async {
    if (fileName.trim().isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'Cannot be empty');
    }
    if (contentLength < 0) {
      throw ArgumentError.value(
        contentLength,
        'contentLength',
        'Cannot be negative',
      );
    }

    final response = await _sendWithPolicy(
      method: 'POST',
      path: '/File/Upload',
      cancellationToken: cancellationToken,
      retryable: false,
      requestBuilder: (uri, abortTrigger) {
        return _buildMultipartRequest(
          uri,
          abortTrigger,
          stream: stream,
          contentLength: contentLength,
          fileName: fileName,
        );
      },
    );
    return _parseServerData(
      () => WiroUploadResult.fromJson(_decodeResponse(response)),
    );
  }

  /// Emits polled task snapshots until the task reaches a terminal status.
  ///
  /// Cancelling the stream does not abort an in-flight HTTP request. Supply a
  /// [cancellationToken] when request cancellation is required.
  @override
  Stream<WiroTask> watchTask(
    WiroTaskToken taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  }) async* {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Must be greater than zero',
      );
    }

    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      cancellationToken?.throwIfCancelled();
      final task = await getTask(
        taskToken,
        cancellationToken: cancellationToken,
      );
      yield task;
      if (task.status.isTerminal) {
        return;
      }

      final remaining = deadline.difference(DateTime.now());
      final delay = remaining < pollInterval ? remaining : pollInterval;
      await _cancellableDelay(delay, cancellationToken);
    }

    throw WiroTimeoutException(
      'Task did not finish within ${timeout.inSeconds} seconds.',
      timeout: timeout,
    );
  }

  /// Streams realtime task events from Wiro over WebSocket.
  ///
  /// The client registers [taskToken] using Wiro's `task_info` protocol and
  /// closes the connection after `task_postprocess_end` or `task_cancel`.
  /// JSON frames are emitted as [WiroSocketMessageEvent], while realtime
  /// binary frames are emitted as [WiroSocketBinaryEvent].
  @override
  Stream<WiroSocketEvent> watchTaskSocket(
    WiroTaskToken taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  }) async* {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Must be greater than zero',
      );
    }

    cancellationToken?.throwIfCancelled();
    final channel = WebSocketChannel.connect(_socketUri);
    var timedOut = false;
    Timer? timer;

    _log(
      WiroLogEvent(
        level: WiroLogLevel.debug,
        message: 'Connecting to the Wiro task WebSocket.',
        uri: _socketUri,
      ),
    );

    try {
      final readyFutures = <Future<void>>[
        channel.ready,
        if (cancellationToken != null) cancellationToken.whenCancelled,
      ];
      await Future.any(readyFutures).timeout(requestTimeout);
      cancellationToken?.throwIfCancelled();

      channel.sink.add(
        jsonEncode({'type': 'task_info', 'tasktoken': taskToken.value}),
      );
      _log(
        WiroLogEvent(
          level: WiroLogLevel.info,
          message: 'Wiro task WebSocket connected.',
          uri: _socketUri,
        ),
      );

      timer = Timer(timeout, () {
        timedOut = true;
        unawaited(channel.sink.close());
      });
      if (cancellationToken != null) {
        unawaited(
          cancellationToken.whenCancelled.then((_) => channel.sink.close()),
        );
      }

      await for (final frame in channel.stream) {
        cancellationToken?.throwIfCancelled();
        final event = _decodeSocketEvent(frame);
        yield event;
        if (event case WiroSocketMessageEvent(isTerminal: true)) {
          return;
        }
      }

      cancellationToken?.throwIfCancelled();
      if (timedOut) {
        throw WiroTimeoutException(
          'Task socket did not finish within ${timeout.inSeconds} seconds.',
          timeout: timeout,
        );
      }
      throw const WiroWebSocketException(
        'The Wiro task WebSocket closed before a terminal event.',
      );
    } on WiroRequestCancelledException {
      rethrow;
    } on WiroTimeoutException {
      rethrow;
    } on TimeoutException catch (error) {
      throw WiroTimeoutException(
        'Wiro task WebSocket connection timed out after '
        '${requestTimeout.inSeconds} seconds.',
        timeout: requestTimeout,
        cause: error,
      );
    } on WiroWebSocketException {
      rethrow;
    } on Object catch (error) {
      throw WiroWebSocketException(
        'Unable to communicate with the Wiro task WebSocket.',
        cause: error,
      );
    } finally {
      timer?.cancel();
      await channel.sink.close();
    }
  }

  /// Polls until a task reaches a terminal status.
  @override
  Future<WiroTask> waitForTask(
    WiroTaskToken taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  }) async {
    await for (final task in watchTask(
      taskToken,
      timeout: timeout,
      cancellationToken: cancellationToken,
    )) {
      if (task.status.isTerminal) {
        return task;
      }
    }

    throw WiroTimeoutException(
      'Task did not finish within ${timeout.inSeconds} seconds.',
      timeout: timeout,
    );
  }

  /// Releases the internally created HTTP client.
  ///
  /// A client injected through the constructor remains owned by the caller.
  @override
  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<T> _post<T>(
    String path,
    WiroJson body,
    T Function(WiroJson json) fromJson, {
    WiroCancellationToken? cancellationToken,
    bool retryable = true,
  }) async {
    final response = await _sendWithPolicy(
      method: 'POST',
      path: path,
      cancellationToken: cancellationToken,
      retryable: retryable,
      requestBuilder: (uri, abortTrigger) {
        return http.AbortableRequest('POST', uri, abortTrigger: abortTrigger)
          ..headers.addAll(_authHeaders())
          ..body = jsonEncode(body);
      },
    );
    return _parseServerData(() => fromJson(_decodeResponse(response)));
  }

  Future<http.Response> _sendWithPolicy({
    required String method,
    required String path,
    required _RequestBuilder requestBuilder,
    WiroCancellationToken? cancellationToken,
    bool retryable = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    for (var attempt = 0; ; attempt++) {
      cancellationToken?.throwIfCancelled();
      try {
        final response = await _sendAttempt(
          method: method,
          uri: uri,
          requestBuilder: requestBuilder,
          cancellationToken: cancellationToken,
        );
        final shouldRetry =
            retryable &&
            retryPolicy.shouldRetryStatus(response.statusCode) &&
            attempt < retryPolicy.maxRetries;
        if (!shouldRetry) {
          return response;
        }
        await _beforeRetry(
          method: method,
          uri: uri,
          attempt: attempt,
          statusCode: response.statusCode,
          minimumDelay: response.statusCode == 429
              ? _retryAfter(response)
              : null,
          cancellationToken: cancellationToken,
        );
      } on WiroRequestCancelledException {
        rethrow;
      } on WiroNetworkException catch (error) {
        if (!retryable || attempt >= retryPolicy.maxRetries) {
          _logFailure(method: method, uri: uri, error: error);
          rethrow;
        }
        await _beforeRetry(
          method: method,
          uri: uri,
          attempt: attempt,
          error: error,
          cancellationToken: cancellationToken,
        );
      } on WiroTimeoutException catch (error) {
        if (!retryable || attempt >= retryPolicy.maxRetries) {
          _logFailure(method: method, uri: uri, error: error);
          rethrow;
        }
        await _beforeRetry(
          method: method,
          uri: uri,
          attempt: attempt,
          error: error,
          cancellationToken: cancellationToken,
        );
      }
    }
  }

  Future<http.Response> _sendAttempt({
    required String method,
    required Uri uri,
    required _RequestBuilder requestBuilder,
    WiroCancellationToken? cancellationToken,
  }) async {
    final timeoutSignal = Completer<void>();
    var timedOut = false;
    final timer = Timer(requestTimeout, () {
      timedOut = true;
      timeoutSignal.complete();
    });
    final abortTrigger = cancellationToken == null
        ? timeoutSignal.future
        : Future.any([timeoutSignal.future, cancellationToken.whenCancelled]);
    final stopwatch = Stopwatch()..start();

    _log(
      WiroLogEvent(
        level: WiroLogLevel.debug,
        message: 'Sending Wiro request.',
        method: method,
        uri: uri,
      ),
    );

    try {
      final request = await requestBuilder(uri, abortTrigger);
      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      _log(
        WiroLogEvent(
          level: WiroLogLevel.info,
          message: 'Wiro request completed.',
          method: method,
          uri: uri,
          statusCode: response.statusCode,
          duration: stopwatch.elapsed,
        ),
      );
      return response;
    } on http.RequestAbortedException catch (error) {
      if (cancellationToken?.isCancelled ?? false) {
        throw const WiroRequestCancelledException();
      }
      if (timedOut) {
        throw WiroTimeoutException(
          'Wiro request timed out after '
          '${requestTimeout.inSeconds} seconds.',
          timeout: requestTimeout,
          cause: error,
        );
      }
      throw WiroNetworkException('The Wiro request was aborted.', cause: error);
    } on http.ClientException catch (error) {
      throw WiroNetworkException(
        'Unable to communicate with the Wiro API.',
        cause: error,
      );
    } finally {
      timer.cancel();
      stopwatch.stop();
    }
  }

  Future<void> _beforeRetry({
    required String method,
    required Uri uri,
    required int attempt,
    WiroCancellationToken? cancellationToken,
    int? statusCode,
    Duration? minimumDelay,
    Object? error,
  }) async {
    final policyDelay = retryPolicy.delayFor(attempt);
    final delay = minimumDelay != null && minimumDelay > policyDelay
        ? minimumDelay
        : policyDelay;
    _log(
      WiroLogEvent(
        level: WiroLogLevel.warning,
        message: 'Retrying Wiro request.',
        method: method,
        uri: uri,
        statusCode: statusCode,
        retryCount: attempt + 1,
        error: error,
      ),
    );
    await _cancellableDelay(delay, cancellationToken);
  }

  Future<void> _cancellableDelay(
    Duration duration,
    WiroCancellationToken? cancellationToken,
  ) async {
    if (duration <= Duration.zero) {
      cancellationToken?.throwIfCancelled();
      return;
    }
    if (cancellationToken == null) {
      await Future<void>.delayed(duration);
      return;
    }

    await Future.any([
      Future<void>.delayed(duration),
      cancellationToken.whenCancelled,
    ]);
    cancellationToken.throwIfCancelled();
  }

  http.BaseRequest _buildMultipartRequest(
    Uri uri,
    Future<void> abortTrigger, {
    required Stream<List<int>> stream,
    required int contentLength,
    required String fileName,
  }) {
    final multipart = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders(includeContentType: false))
      ..files.add(
        http.MultipartFile('file', stream, contentLength, filename: fileName),
      );
    final body = multipart.finalize();
    final request =
        http.AbortableStreamedRequest('POST', uri, abortTrigger: abortTrigger)
          ..headers.addAll(multipart.headers)
          ..contentLength = multipart.contentLength;

    body.listen(
      request.sink.add,
      onError: request.sink.addError,
      onDone: request.sink.close,
      cancelOnError: true,
    );
    return request;
  }

  Map<String, String> _authHeaders({bool includeContentType = true}) {
    final headers = <String, String>{..._extraHeaders};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    final apiKey = _apiKey;
    if (apiKey == null) {
      return headers;
    }
    headers['x-api-key'] = apiKey;

    final apiSecret = _apiSecret;
    if (apiSecret != null) {
      final nonce = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = Hmac(
        sha256,
        utf8.encode(apiKey),
      ).convert(utf8.encode('$apiSecret$nonce'));
      headers['x-signature'] = '$signature';
      headers['x-nonce'] = nonce;
    }

    return headers;
  }

  WiroJson _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionForResponse(response);
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded case final Map<String, dynamic> json) {
        final result = json.cast<String, Object?>();
        if (!JsonReader.boolean(result['result'], fallback: true)) {
          throw _exceptionForApiResult(response, result);
        }
        return result;
      }
      throw const FormatException('Expected a JSON object');
    } on FormatException catch (error) {
      throw WiroUnknownApiException(
        'The Wiro API returned invalid JSON.',
        statusCode: response.statusCode,
        responseBody: response.body,
        cause: error,
      );
    }
  }

  WiroApiException _exceptionForResponse(http.Response response) {
    final message = _responseErrorMessage(response.body);
    final exception = switch (response.statusCode) {
      401 || 403 => WiroAuthenticationException(
        message,
        statusCode: response.statusCode,
        responseBody: response.body,
      ),
      400 || 422 => WiroValidationException(
        message,
        statusCode: response.statusCode,
        responseBody: response.body,
      ),
      429 => WiroRateLimitException(
        message,
        statusCode: response.statusCode,
        responseBody: response.body,
        retryAfter: _retryAfter(response),
      ),
      _ => WiroUnknownApiException(
        message,
        statusCode: response.statusCode,
        responseBody: response.body,
      ),
    };
    _logApiFailure(response, exception.message);
    return exception;
  }

  WiroApiResultException _exceptionForApiResult(
    http.Response response,
    WiroJson json,
  ) {
    final errors = JsonReader.list(json['errors']);
    final firstError = errors.isEmpty
        ? const <String, Object?>{}
        : JsonReader.map(errors.first);
    final exception = WiroApiResultException(
      _responseErrorMessage(response.body),
      statusCode: response.statusCode,
      responseBody: response.body,
      code: JsonReader.string(firstError['code']),
    );
    _logApiFailure(response, exception.message);
    return exception;
  }

  void _logApiFailure(http.Response response, String message) {
    _log(
      WiroLogEvent(
        level: WiroLogLevel.error,
        message: message,
        method: response.request?.method,
        uri: response.request?.url,
        statusCode: response.statusCode,
      ),
    );
  }

  String _responseErrorMessage(String body) {
    try {
      final json = JsonReader.map(jsonDecode(body));
      final errors = JsonReader.list(json['errors']);
      if (errors.isNotEmpty) {
        final message = JsonReader.string(
          JsonReader.map(errors.first)['message'],
        );
        if (message != null) {
          return message;
        }
      }
      return JsonReader.string(json['message']) ?? 'Wiro API request failed.';
    } on FormatException {
      return body.isEmpty ? 'Wiro API request failed.' : body;
    }
  }

  Duration? _retryAfter(http.Response response) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  void _log(WiroLogEvent event) {
    logger?.call(event);
  }

  T _parseServerData<T>(T Function() parse) {
    return JsonReader.runWithMalformedJsonHandler((_, error) {
      _log(
        WiroLogEvent(
          level: WiroLogLevel.debug,
          message: 'Ignored malformed nested JSON in a Wiro response.',
          error: error,
        ),
      );
    }, parse);
  }

  void _logFailure({
    required String method,
    required Uri uri,
    required WiroException error,
  }) {
    _log(
      WiroLogEvent(
        level: WiroLogLevel.error,
        message: error.message,
        method: method,
        uri: uri,
        error: error,
      ),
    );
  }

  static WiroModelSchema _modelSchemaFromResponse(WiroJson json) {
    final models = JsonReader.list(json['tool']);
    if (models.isEmpty) {
      throw WiroUnknownApiException(
        'The model schema response did not contain a model.',
        statusCode: 200,
        responseBody: jsonEncode(json),
      );
    }
    return WiroModelSchema.fromJson(JsonReader.map(models.first));
  }

  static WiroTask _taskFromResponse(WiroJson json) {
    final tasks = JsonReader.list(json['tasklist']);
    if (tasks.isEmpty) {
      throw WiroUnknownApiException(
        'The task response did not contain a task.',
        statusCode: 200,
        responseBody: jsonEncode(json),
      );
    }
    return WiroTask.fromJson(JsonReader.map(tasks.first));
  }

  WiroSocketEvent _decodeSocketEvent(Object? frame) {
    if (frame case final List<int> bytes) {
      return WiroSocketBinaryEvent(bytes);
    }
    if (frame case final String text) {
      try {
        final decoded = jsonDecode(text);
        if (decoded case final Map<String, dynamic> json) {
          return _parseServerData(
            () => WiroSocketMessageEvent.fromJson(json.cast<String, Object?>()),
          );
        }
      } on FormatException catch (error) {
        throw WiroWebSocketException(
          'The Wiro task WebSocket returned invalid JSON.',
          cause: error,
        );
      }
      throw const WiroWebSocketException(
        'The Wiro task WebSocket returned a non-object JSON payload.',
      );
    }
    throw WiroWebSocketException(
      'The Wiro task WebSocket returned an unsupported frame type: '
      '${frame.runtimeType}.',
    );
  }

  static String _normalizeBaseUrl(Uri uri) {
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  static Uri _validateHttpOrigin(Uri uri, String name) {
    final hasHttpScheme = uri.scheme == 'https' || uri.scheme == 'http';
    if (!hasHttpScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        uri,
        name,
        'Must be an HTTP(S) origin without credentials, query, or fragment',
      );
    }
    return uri;
  }

  static void _validateTimings(Duration requestTimeout, Duration pollInterval) {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be greater than zero',
      );
    }
    if (pollInterval < Duration.zero) {
      throw ArgumentError.value(
        pollInterval,
        'pollInterval',
        'Cannot be negative',
      );
    }
  }

  static Uri _validateCallbackUrl(Uri uri) {
    final hasHttpScheme = uri.scheme == 'https' || uri.scheme == 'http';
    if (!hasHttpScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw ArgumentError.value(
        uri,
        'callbackUrl',
        'Must be an HTTP(S) URL without credentials or a fragment',
      );
    }
    return uri;
  }

  static Uri _validateSocketUri(Uri uri) {
    final hasSocketScheme = uri.scheme == 'wss' || uri.scheme == 'ws';
    if (!hasSocketScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        uri,
        'socketUri',
        'Must be a WS(S) URL without credentials, query, or fragment',
      );
    }
    return uri;
  }
}

typedef _RequestBuilder =
    FutureOr<http.BaseRequest> Function(Uri uri, Future<void> abortTrigger);
