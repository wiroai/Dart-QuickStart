import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:wiro_ai/src/model/json_reader.dart';
import 'package:wiro_ai/src/model/wiro_json.dart';
import 'package:wiro_ai/src/model/wiro_model.dart';
import 'package:wiro_ai/src/model/wiro_result.dart';
import 'package:wiro_ai/src/model/wiro_task.dart';
import 'package:wiro_ai/src/wiro_exception.dart';
import 'package:wiro_ai/src/wiro_request.dart';

/// Authentication method used by [WiroClient].
enum WiroAuthType {
  /// Sends only the API key.
  apiKey,

  /// Signs every request with the API key and secret.
  signature,
}

/// Client for the Wiro model and task APIs.
final class WiroClient {
  /// Creates a Wiro API client.
  WiroClient({
    required String apiKey,
    String? apiSecret,
    Uri? baseUri,
    http.Client? httpClient,
    this.pollInterval = const Duration(seconds: 3),
    this.requestTimeout = const Duration(seconds: 30),
    this.retryPolicy = const WiroRetryPolicy(),
    this.logger,
  }) : _apiKey = apiKey,
       // The public parameter intentionally omits the private field prefix.
       // ignore: prefer_initializing_formals
       _apiSecret = apiSecret,
       _baseUrl = _normalizeBaseUrl(baseUri ?? defaultBaseUri),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'Cannot be empty');
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

  final String _apiKey;
  final String? _apiSecret;
  final String _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  /// Delay between task status requests.
  final Duration pollInterval;

  /// Maximum duration of an individual HTTP request.
  final Duration requestTimeout;

  /// Retry behavior for transient HTTP and network failures.
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
  Future<WiroRunResult> runModel(
    String model, {
    WiroJson parameters = const {},
    WiroCancellationToken? cancellationToken,
  }) {
    final (:owner, :project) = _parseModel(model);
    return _post(
      '/Run/$owner/$project',
      parameters,
      WiroRunResult.fromJson,
      cancellationToken: cancellationToken,
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
  }) async {
    final response = await _sendWithPolicy(
      method: 'POST',
      path: '/File/Upload',
      cancellationToken: cancellationToken,
      requestBuilder: (uri, abortTrigger) {
        return _buildMultipartRequest(
          uri,
          abortTrigger,
          bytes: bytes,
          fileName: fileName,
        );
      },
    );
    return WiroUploadResult.fromJson(_decodeResponse(response));
  }

  /// Emits task snapshots until the task reaches a terminal status.
  Stream<WiroTask> watchTask(
    String taskToken, {
    Duration timeout = const Duration(minutes: 2),
    WiroCancellationToken? cancellationToken,
  }) async* {
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

  /// Polls until a task reaches a terminal status.
  Future<WiroTask> waitForTask(
    String taskToken, {
    Duration timeout = const Duration(minutes: 2),
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
  }) async {
    final response = await _sendWithPolicy(
      method: 'POST',
      path: path,
      cancellationToken: cancellationToken,
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
          cancellationToken: cancellationToken,
        );
      } on WiroRequestCancelledException {
        rethrow;
      } on WiroNetworkException catch (error) {
        if (attempt >= retryPolicy.maxRetries) {
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
        if (attempt >= retryPolicy.maxRetries) {
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
    Object? error,
  }) async {
    final delay = retryPolicy.delayFor(attempt);
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
    required List<int> bytes,
    required String fileName,
  }) {
    final multipart = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders(includeContentType: false))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
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
        return json.cast<String, Object?>();
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
    _log(
      WiroLogEvent(
        level: WiroLogLevel.error,
        message: exception.message,
        method: response.request?.method,
        uri: response.request?.url,
        statusCode: response.statusCode,
        error: exception,
      ),
    );
    return exception;
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
    final separator = model.indexOf('/');
    if (separator <= 0 || separator == model.length - 1) {
      throw ArgumentError.value(model, 'model', 'Use the "owner/model" format');
    }

    return (
      owner: model.substring(0, separator),
      project: model.substring(separator + 1),
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

  static String _normalizeBaseUrl(Uri uri) {
    return uri.toString().replaceFirst(RegExp(r'/$'), '');
  }
}

typedef _RequestBuilder =
    FutureOr<http.BaseRequest> Function(
      Uri uri,
      Future<void> abortTrigger,
    );
