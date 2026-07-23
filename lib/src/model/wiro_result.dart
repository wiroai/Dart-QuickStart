import 'package:wiro_ai/src/model/json_reader.dart';
import 'package:wiro_ai/src/model/wiro_json.dart';
import 'package:wiro_ai/src/model/wiro_model.dart';

/// An error included in a Wiro API response.
final class WiroApiError {
  const WiroApiError({required this.message, this.code});

  factory WiroApiError.fromJson(WiroJson json) {
    return WiroApiError(
      code: json['code'],
      message: JsonReader.string(json['message']) ?? 'Unknown Wiro API error',
    );
  }

  final Object? code;
  final String message;
}

/// A typed paginated response from Wiro.
final class WiroPaginatedResult<T> {
  const WiroPaginatedResult({
    required this.isSuccess,
    required this.total,
    required this.items,
    required this.errors,
    required this.raw,
  });

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

  final bool isSuccess;
  final int total;
  final List<T> items;
  final List<WiroApiError> errors;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// Result returned immediately after starting a model.
final class WiroRunResult {
  const WiroRunResult({
    required this.isSuccess,
    required this.taskId,
    required this.taskToken,
    required this.errors,
    required this.raw,
  });

  factory WiroRunResult.fromJson(WiroJson json) {
    return WiroRunResult(
      isSuccess: JsonReader.boolean(json['result']),
      taskId: JsonReader.string(json['taskid']) ?? '',
      taskToken: JsonReader.string(json['socketaccesstoken']) ?? '',
      errors: parseWiroApiErrors(json['errors']),
      raw: Map.unmodifiable(json),
    );
  }

  final bool isSuccess;
  final String taskId;

  /// Token used to poll or subscribe to the task.
  final String taskToken;

  final List<WiroApiError> errors;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// Result of a file upload.
final class WiroUploadResult {
  const WiroUploadResult({
    required this.isSuccess,
    required this.files,
    required this.errors,
    required this.raw,
  });

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

  final bool isSuccess;
  final List<WiroUploadedFile> files;
  final List<WiroApiError> errors;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// A file stored by Wiro.
final class WiroUploadedFile {
  const WiroUploadedFile({
    required this.id,
    required this.name,
    required this.contentType,
    required this.size,
    required this.url,
    required this.raw,
  });

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

  final String id;
  final String name;
  final String contentType;
  final int size;
  final Uri? url;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// A curated group returned by the Explore API.
final class WiroExploreCategory {
  const WiroExploreCategory({
    required this.id,
    required this.title,
    required this.models,
    required this.total,
    this.url,
  });

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

  final String id;
  final String title;
  final List<WiroModel> models;
  final int total;
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
