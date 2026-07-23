import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:wiro_ai/src/model/json_reader.dart';
import 'package:wiro_ai/src/model/wiro_json.dart';
import 'package:wiro_ai/src/model/wiro_model.dart';
import 'package:wiro_ai/src/model/wiro_result.dart';
import 'package:wiro_ai/src/model/wiro_task.dart';

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

  final String _apiKey;
  final String? _apiSecret;
  final String _baseUrl;
  final http.Client _httpClient;

  final Duration pollInterval;

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
    );
  }

  /// Returns curated model categories.
  Future<List<WiroExploreCategory>> explore() {
    return _post('/Tool/Explore', const {}, (json) {
      final categories = JsonReader.list(json['explore'])
          .map(JsonReader.map)
          .where((item) => item.isNotEmpty)
          .map(WiroExploreCategory.fromJson);
      return List.unmodifiable(categories);
    });
  }

  /// Returns the input schema for [model].
  Future<WiroModelSchema> getModelSchema(String model) {
    final (:owner, :project) = _parseModel(model);
    return _post('/Tool/Detail', {
      'slugowner': owner,
      'slugproject': project,
    }, _modelSchemaFromResponse);
  }

  /// Starts [model] with the supplied [parameters].
  Future<WiroRunResult> runModel(
    String model, {
    WiroJson parameters = const {},
  }) {
    final (:owner, :project) = _parseModel(model);
    return _post('/Run/$owner/$project', parameters, WiroRunResult.fromJson);
  }

  /// Returns task details using a task token or task ID.
  Future<WiroTask> getTask({String? taskToken, String? taskId}) {
    if (taskToken == null && taskId == null) {
      throw ArgumentError('taskToken or taskId is required');
    }

    return _post('/Task/Detail', {
      'tasktoken': ?taskToken,
      'taskid': ?taskId,
    }, _taskFromResponse);
  }

  /// Requests cancellation of a queued task.
  Future<bool> cancelTask(String taskToken) {
    return _post('/Task/Cancel', {
      'tasktoken': taskToken,
    }, (json) => JsonReader.boolean(json['result']));
  }

  /// Stops a running task.
  Future<bool> killTask(String taskToken) {
    return _post('/Task/Kill', {
      'tasktoken': taskToken,
    }, (json) => JsonReader.boolean(json['result']));
  }

  /// Uploads [bytes] to Wiro.
  Future<WiroUploadResult> uploadFile(
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
    return WiroUploadResult.fromJson(_decodeResponse(response));
  }

  /// Polls until a task reaches a terminal status.
  Future<WiroTask> waitForTask(
    String taskToken, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final task = await getTask(taskToken: taskToken);
      if (task.status.isTerminal) {
        return task;
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

  Future<T> _post<T>(
    String path,
    WiroJson body,
    T Function(WiroJson json) fromJson,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl$path'),
      headers: _authHeaders(),
      body: jsonEncode(body),
    );
    return fromJson(_decodeResponse(response));
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

  static WiroModelSchema _modelSchemaFromResponse(WiroJson json) {
    final models = JsonReader.list(json['tool']);
    if (models.isEmpty) {
      throw const WiroApiException(
        message: 'The model schema response did not contain a model',
      );
    }
    return WiroModelSchema.fromJson(JsonReader.map(models.first));
  }

  static WiroTask _taskFromResponse(WiroJson json) {
    final tasks = JsonReader.list(json['tasklist']);
    if (tasks.isEmpty) {
      throw const WiroApiException(
        message: 'The task response did not contain a task',
      );
    }
    return WiroTask.fromJson(JsonReader.map(tasks.first));
  }

  static String _normalizeBaseUrl(Uri uri) {
    return uri.toString().replaceFirst(RegExp(r'/$'), '');
  }
}
