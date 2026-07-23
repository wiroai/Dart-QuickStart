import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wiro_client/src/model/json_reader.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_model.dart';
import 'package:wiro_client/src/model/wiro_result.dart';
import 'package:wiro_client/src/model/wiro_socket.dart';
import 'package:wiro_client/src/model/wiro_task.dart';
import 'package:wiro_client/src/wiro_exception.dart';
import 'package:wiro_client/src/wiro_request.dart';

/// Authentication method used by [WiroClient].
enum WiroAuthType {
  /// Sends only the API key.
  apiKey,

  /// Signs every request with the API key and secret.
  signature,
}

/// Receives a task snapshot while [WiroClient.subscribe] is polling.
typedef WiroTaskUpdateCallback = void Function(WiroTask task);

/// Client for the Wiro model and task APIs.
final class WiroClient {
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
       // The public parameter intentionally omits the private field prefix.
       // ignore: prefer_initializing_formals
       _apiSecret = apiSecret,
       _baseUrl = _normalizeBaseUrl(
         _validateBaseUri(baseUri ?? defaultBaseUri),
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

  /// Default Wiro REST API endpoint.
  static final Uri defaultBaseUri = Uri.parse('https://api.wiro.ai/v1');

  /// Default Wiro task WebSocket endpoint.
  static final Uri defaultSocketUri = Uri.parse('wss://socket.wiro.ai/v1');

  final String _apiKey;
  final String? _apiSecret;
  final String _baseUrl;
  final Uri _socketUri;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// Delay between task status requests.
  final Duration pollInterval;

  /// Maximum duration of an individual HTTP request.
  final Duration requestTimeout;

  /// Retry behavior for safe read-like HTTP operations.
  ///
  /// Model runs and file uploads are never retried automatically.
  final WiroRetryPolicy retryPolicy;

  /// Optional structured diagnostic event receiver.
  final WiroLogger? logger;

  /// Authentication method inferred from the configured credentials.
  WiroAuthType get authType {
    return _apiSecret == null ? WiroAuthType.apiKey : WiroAuthType.signature;
  }

  /// Searches the models available on Wiro.
  Future<WiroPaginatedResult<WiroModel>> searchModels({
    String search = '',
    List<String> categories = const [],
    int start = 0,
    int limit = 20,
    String sort = 'relevance',
    String? owner,
    String? order,
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
        'sort': sort,
        'hideworkflows': true,
        'summary': true,
        'slugowner': ?owner,
        'order': ?order,
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
  Future<WiroModelSchema> getModelSchema(
    String model, {
    WiroCancellationToken? cancellationToken,
  }) {
    final (:owner, :project) = _parseModel(model);
    return _post(
      '/Tool/Detail',
      {'slugowner': owner, 'slugproject': project},
      _modelSchemaFromResponse,
      cancellationToken: cancellationToken,
    );
  }

  /// Starts [model] with the supplied dynamic [parameters].
  ///
  /// When [callbackUrl] is supplied, Wiro sends the completed task to that
  /// webhook URL.
  ///
  /// This billable operation is not retried automatically.
  Future<WiroRunResult> runModel(
    String model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    WiroCancellationToken? cancellationToken,
  }) {
    final (:owner, :project) = _parseModel(model);
    final callback = callbackUrl == null
        ? null
        : _validateCallbackUrl(callbackUrl);
    return _post(
      '/Run/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(project)}',
      {
        ...parameters,
        if (callback != null) 'callbackUrl': callback.toString(),
      },
      WiroRunResult.fromJson,
      cancellationToken: cancellationToken,
      retryable: false,
    );
  }

  /// Starts [model], polls it to completion, and returns its terminal task.
  ///
  /// [onTaskUpdate] receives every polled task snapshot. By default a terminal
  /// task that did not succeed throws [WiroTaskFailedException]. Set
  /// [throwOnTaskFailure] to `false` to inspect that task directly.
  Future<WiroTask> subscribe(
    String model, {
    WiroJson parameters = const {},
    Uri? callbackUrl,
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
    WiroTaskUpdateCallback? onTaskUpdate,
    bool throwOnTaskFailure = true,
  }) async {
    final run = await runModel(
      model,
      parameters: parameters,
      callbackUrl: callbackUrl,
      cancellationToken: cancellationToken,
    );

    await for (final task in watchTask(
      run.taskToken,
      timeout: timeout,
      cancellationToken: cancellationToken,
    )) {
      onTaskUpdate?.call(task);
      if (task.status.isTerminal) {
        if (throwOnTaskFailure && !task.isSuccessful) {
          throw WiroTaskFailedException(task);
        }
        return task;
      }
    }

    throw WiroTimeoutException(
      'Task did not finish within ${timeout.inSeconds} seconds.',
      timeout: timeout,
    );
  }

  /// Returns task details using a task token or task ID.
  Future<WiroTask> getTask({
    String? taskToken,
    String? taskId,
    WiroCancellationToken? cancellationToken,
  }) {
    if (taskToken == null && taskId == null) {
      throw ArgumentError('taskToken or taskId is required');
    }
    if (taskToken != null) {
      _validateToken(taskToken, 'taskToken');
    }
    if (taskId != null) {
      _validateToken(taskId, 'taskId');
    }

    return _post(
      '/Task/Detail',
      {
        'tasktoken': ?taskToken,
        'taskid': ?taskId,
      },
      _taskFromResponse,
      cancellationToken: cancellationToken,
    );
  }

  /// Requests cancellation of a queued task.
  Future<bool> cancelTask(
    String taskToken, {
    WiroCancellationToken? cancellationToken,
  }) {
    _validateToken(taskToken, 'taskToken');
    return _post(
      '/Task/Cancel',
      {'tasktoken': taskToken},
      (json) => JsonReader.boolean(json['result']),
      cancellationToken: cancellationToken,
    );
  }

  /// Stops a running task.
  Future<bool> killTask(
    String taskToken, {
    WiroCancellationToken? cancellationToken,
  }) {
    _validateToken(taskToken, 'taskToken');
    return _post(
      '/Task/Kill',
      {'tasktoken': taskToken},
      (json) => JsonReader.boolean(json['result']),
      cancellationToken: cancellationToken,
    );
  }

  /// Uploads [bytes] to Wiro.
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
    return WiroUploadResult.fromJson(_decodeResponse(response));
  }

  /// Emits polled task snapshots until the task reaches a terminal status.
  ///
  /// Cancelling the stream does not abort an in-flight HTTP request. Supply a
  /// [cancellationToken] when request cancellation is required.
  Stream<WiroTask> watchTask(
    String taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  }) async* {
    _validateToken(taskToken, 'taskToken');
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
        taskToken: taskToken,
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
  Stream<WiroSocketEvent> watchTaskSocket(
    String taskToken, {
    Duration timeout = const Duration(minutes: 10),
    WiroCancellationToken? cancellationToken,
  }) async* {
    _validateToken(taskToken, 'taskToken');
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
        jsonEncode({'type': 'task_info', 'tasktoken': taskToken}),
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
  Future<WiroTask> waitForTask(
    String taskToken, {
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
        return http.AbortableRequest(
            'POST',
            uri,
            abortTrigger: abortTrigger,
          )
          ..headers.addAll(_authHeaders())
          ..body = jsonEncode(body);
      },
    );
    return fromJson(_decodeResponse(response));
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
      throw WiroNetworkException(
        'The Wiro request was aborted.',
        cause: error,
      );
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
        http.MultipartFile(
          'file',
          stream,
          contentLength,
          filename: fileName,
        ),
      );
    final body = multipart.finalize();
    final request =
        http.AbortableStreamedRequest(
            'POST',
            uri,
            abortTrigger: abortTrigger,
          )
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
    final headers = <String, String>{'x-api-key': _apiKey};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    final apiSecret = _apiSecret;
    if (apiSecret != null) {
      final nonce = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = Hmac(
        sha256,
        utf8.encode(_apiKey),
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
      code: firstError['code'],
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

  static ({String owner, String project}) _parseModel(String model) {
    final parts = model.split('/');
    final slugPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
    if (parts.length != 2 ||
        !slugPattern.hasMatch(parts.first) ||
        !slugPattern.hasMatch(parts.last)) {
      throw ArgumentError.value(model, 'model', 'Use the "owner/model" format');
    }

    return (
      owner: parts.first,
      project: parts.last,
    );
  }

  static void _validateToken(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Cannot be empty');
    }
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

  static WiroSocketEvent _decodeSocketEvent(Object? frame) {
    if (frame case final List<int> bytes) {
      return WiroSocketBinaryEvent(bytes);
    }
    if (frame case final String text) {
      try {
        final decoded = jsonDecode(text);
        if (decoded case final Map<String, dynamic> json) {
          return WiroSocketMessageEvent.fromJson(
            json.cast<String, Object?>(),
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

  static Uri _validateBaseUri(Uri uri) {
    final hasHttpScheme = uri.scheme == 'https' || uri.scheme == 'http';
    if (!hasHttpScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        uri,
        'baseUri',
        'Must be an HTTP(S) origin without credentials, query, or fragment',
      );
    }
    return uri;
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
    FutureOr<http.BaseRequest> Function(
      Uri uri,
      Future<void> abortTrigger,
    );
