import 'package:wiro_ai/src/model/json_reader.dart';
import 'package:wiro_ai/src/model/wiro_json.dart';
import 'package:wiro_ai/src/model/wiro_model.dart';

/// An error included in a Wiro API response.
final class WiroApiError {
  /// Creates an API error.
  const WiroApiError({required this.message, this.code});

  /// Creates an API error from a Wiro payload.
  factory WiroApiError.fromJson(WiroJson json) {
    return WiroApiError(
      code: json['code'],
      message: JsonReader.string(json['message']) ?? 'Unknown Wiro API error',
    );
  }

  /// Machine-readable error code, when provided.
  final Object? code;

  /// Human-readable error message.
  final String message;
}

/// A typed paginated response from Wiro.
final class WiroPaginatedResult<T> {
  /// Creates a paginated result.
  const WiroPaginatedResult({
    required this.isSuccess,
    required this.total,
    required this.items,
    required this.errors,
    required this.raw,
  });

  /// Parses a paginated response using [itemFromJson] for each item.
  factory WiroPaginatedResult.fromJson(
    WiroJson json, {
    required String itemsKey,
    required T Function(WiroJson json) itemFromJson,
  }) {
    final items = JsonReader.list(json[itemsKey])
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(itemFromJson)
        .toList(growable: false);

    return WiroPaginatedResult(
      isSuccess: JsonReader.boolean(json['result']),
      total: JsonReader.integer(json['total'], fallback: items.length),
      items: List.unmodifiable(items),
      errors: parseWiroApiErrors(json['errors']),
      raw: Map.unmodifiable(json),
    );
  }

  /// Whether Wiro marked the request as successful.
  final bool isSuccess;

  /// Total number of available items.
  final int total;

  /// Items returned on this page.
  final List<T> items;

  /// API errors returned with the response.
  final List<WiroApiError> errors;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// Result returned immediately after starting a model.
final class WiroRunResult {
  /// Creates a model-run result.
  const WiroRunResult({
    required this.isSuccess,
    required this.taskId,
    required this.taskToken,
    required this.errors,
    required this.raw,
  });

  /// Creates a model-run result from a Wiro payload.
  factory WiroRunResult.fromJson(WiroJson json) {
    return WiroRunResult(
      isSuccess: JsonReader.boolean(json['result']),
      taskId: JsonReader.string(json['taskid']) ?? '',
      taskToken: JsonReader.string(json['socketaccesstoken']) ?? '',
      errors: parseWiroApiErrors(json['errors']),
      raw: Map.unmodifiable(json),
    );
  }

  /// Whether Wiro accepted the model run.
  final bool isSuccess;

  /// Server-side task identifier.
  final String taskId;

  /// Token used to poll or subscribe to the task.
  final String taskToken;

  /// API errors returned with the response.
  final List<WiroApiError> errors;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// Result of a file upload.
final class WiroUploadResult {
  /// Creates an upload result.
  const WiroUploadResult({
    required this.isSuccess,
    required this.files,
    required this.errors,
    required this.raw,
  });

  /// Creates an upload result from a Wiro payload.
  factory WiroUploadResult.fromJson(WiroJson json) {
    final files = JsonReader.list(json['list'])
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroUploadedFile.fromJson)
        .toList(growable: false);

    return WiroUploadResult(
      isSuccess: JsonReader.boolean(json['result']),
      files: List.unmodifiable(files),
      errors: parseWiroApiErrors(json['errors']),
      raw: Map.unmodifiable(json),
    );
  }

  /// Whether Wiro accepted the upload.
  final bool isSuccess;

  /// Files created by the upload.
  final List<WiroUploadedFile> files;

  /// API errors returned with the response.
  final List<WiroApiError> errors;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// A file stored by Wiro.
final class WiroUploadedFile {
  /// Creates an uploaded file descriptor.
  const WiroUploadedFile({
    required this.id,
    required this.name,
    required this.contentType,
    required this.size,
    required this.url,
    required this.raw,
  });

  /// Creates a file descriptor from a Wiro payload.
  factory WiroUploadedFile.fromJson(WiroJson json) {
    return WiroUploadedFile(
      id: JsonReader.string(json['id']) ?? '',
      name: JsonReader.string(json['name']) ?? '',
      contentType: JsonReader.string(json['contenttype']) ?? '',
      size: JsonReader.integer(json['size']),
      url: JsonReader.uri(json['url']),
      raw: Map.unmodifiable(json),
    );
  }

  /// Wiro file identifier.
  final String id;

  /// Original file name.
  final String name;

  /// MIME content type.
  final String contentType;

  /// File size in bytes.
  final int size;

  /// Public or authenticated file URL.
  final Uri? url;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// A curated group returned by the Explore API.
final class WiroExploreCategory {
  /// Creates an explore category.
  const WiroExploreCategory({
    required this.id,
    required this.title,
    required this.models,
    required this.total,
    this.url,
  });

  /// Creates an explore category from a Wiro payload.
  factory WiroExploreCategory.fromJson(WiroJson json) {
    final models = JsonReader.list(json['tools'])
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroModel.fromJson)
        .toList(growable: false);

    return WiroExploreCategory(
      id: JsonReader.string(json['id']) ?? '',
      title: JsonReader.string(json['title']) ?? '',
      models: List.unmodifiable(models),
      total: JsonReader.integer(json['total'], fallback: models.length),
      url: JsonReader.uri(json['url']),
    );
  }

  /// Category identifier.
  final String id;

  /// Display title.
  final String title;

  /// Curated models in this category.
  final List<WiroModel> models;

  /// Total number of models in this category.
  final int total;

  /// Optional category URL.
  final Uri? url;
}

/// Parses the common `errors` collection used by Wiro responses.
List<WiroApiError> parseWiroApiErrors(Object? value) {
  return List.unmodifiable(
    JsonReader.list(value)
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroApiError.fromJson),
  );
}
