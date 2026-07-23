import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// A JSON object returned by the Wiro API.
typedef WiroJson = Map<String, Object?>;

/// Authentication method used by [WiroClient].
enum WiroAuthType { apiKey, signature }

/// An exception returned by the Wiro API.
final class WiroApiException implements Exception {
  const WiroApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'WiroApiException$status: $message';
  }
}

/// Client for the Wiro model and task APIs.
final class WiroClient {
  WiroClient({
    required String apiKey,
    String? apiSecret,
    Uri? baseUri,
    http.Client? httpClient,
    this.pollInterval = const Duration(seconds: 3),
  }) : _apiKey = apiKey,
       // The public parameter intentionally omits the private field prefix.
       // ignore: prefer_initializing_formals
       _apiSecret = apiSecret,
       _baseUrl = _normalizeBaseUrl(baseUri ?? defaultBaseUri),
       _httpClient = httpClient ?? http.Client() {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'Cannot be empty');
    }
  }

  static final Uri defaultBaseUri = Uri.parse('https://api.wiro.ai/v1');

  static const Set<String> terminalTaskStatuses = {
    'task_postprocess_end',
    'task_cancel',
  };

  final String _apiKey;
  final String? _apiSecret;
  final String _baseUrl;
  final http.Client _httpClient;

  final Duration pollInterval;

  WiroAuthType get authType {
    return _apiSecret == null ? WiroAuthType.apiKey : WiroAuthType.signature;
  }

  /// Searches the models available on Wiro.
  Future<WiroJson> searchModels({
    String search = '',
    List<String> categories = const [],
    int start = 0,
    int limit = 20,
    String sort = 'relevance',
    String? owner,
    String? order,
  }) {
    return _post('/Tool/List', {
      'start': '$start',
      'limit': '$limit',
      'search': search,
      'categories': categories,
      'sort': sort,
      'hideworkflows': true,
      'summary': true,
      'slugowner': ?owner,
      'order': ?order,
    });
  }

  /// Returns curated model categories.
  Future<WiroJson> explore() => _post('/Tool/Explore', const {});

  /// Returns the input schema for [model].
  Future<WiroJson> getModelSchema(String model) {
    final (:owner, :project) = _parseModel(model);
    return _post('/Tool/Detail', {'slugowner': owner, 'slugproject': project});
  }

  /// Starts [model] with the supplied [parameters].
  Future<WiroJson> runModel(String model, {WiroJson parameters = const {}}) {
    final (:owner, :project) = _parseModel(model);
    return _post('/Run/$owner/$project', parameters);
  }

  /// Returns task details using a task token or task ID.
  Future<WiroJson> getTask({String? taskToken, String? taskId}) {
    if (taskToken == null && taskId == null) {
      throw ArgumentError('taskToken or taskId is required');
    }

    return _post('/Task/Detail', {'tasktoken': ?taskToken, 'taskid': ?taskId});
  }

  /// Requests cancellation of a queued task.
  Future<WiroJson> cancelTask(String taskToken) {
    return _post('/Task/Cancel', {'tasktoken': taskToken});
  }

  /// Stops a running task.
  Future<WiroJson> killTask(String taskToken) {
    return _post('/Task/Kill', {'tasktoken': taskToken});
  }

  /// Uploads [bytes] to Wiro.
  Future<WiroJson> uploadFile(
    List<int> bytes, {
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/File/Upload'),
    );
    request.headers.addAll(_authHeaders(includeContentType: false));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _decodeResponse(response);
  }

  /// Polls until a task reaches a terminal status.
  Future<WiroJson> waitForTask(
    String taskToken, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final detail = await getTask(taskToken: taskToken);
      final status = _firstTaskStatus(detail);
      if (status != null && terminalTaskStatuses.contains(status)) {
        return detail;
      }
      await Future<void>.delayed(pollInterval);
    }

    throw TimeoutException(
      'Task did not finish within ${timeout.inSeconds} seconds.',
      timeout,
    );
  }

  /// Releases the underlying HTTP client.
  void close() => _httpClient.close();

  Future<WiroJson> _post(String path, WiroJson body) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl$path'),
      headers: _authHeaders(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
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
      throw WiroApiException(
        message: 'Wiro API request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded case final Map<String, dynamic> json) {
        return json.cast<String, Object?>();
      }
      throw const FormatException('Expected a JSON object');
    } on FormatException catch (error) {
      throw WiroApiException(
        message: 'Invalid JSON response: ${error.message}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
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

  static String? _firstTaskStatus(WiroJson detail) {
    final tasks = detail['tasklist'];
    if (tasks case [final Map<Object?, Object?> first, ...]) {
      return first['status'] as String?;
    }
    return null;
  }

  static String _normalizeBaseUrl(Uri uri) {
    return uri.toString().replaceFirst(RegExp(r'/$'), '');
  }
}
