import 'package:wiro_client/src/model/json_reader.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';

/// Lifecycle state of a Wiro task.
enum WiroTaskStatus {
  /// Waiting for an available worker.
  queued('task_queue'),

  /// Accepted by a worker.
  accepted('task_accept'),

  /// Preparing inputs.
  preprocessing('task_preprocess_start'),

  /// Input preparation finished.
  preprocessed('task_preprocess_end'),

  /// Assigned to a worker.
  assigned('task_assign'),

  /// Model process is running.
  running('task_start'),

  /// Model produced an incremental output.
  output('task_output'),

  /// Complete standard output is available.
  outputComplete('task_output_full'),

  /// Model produced an incremental error log.
  errorOutput('task_error'),

  /// Complete error log is available.
  errorOutputComplete('task_error_full'),

  /// Model process exited and post-processing may follow.
  processEnded('task_end'),

  /// Output files are being prepared.
  postProcessing('task_postprocess_start'),

  /// Post-processing finished.
  completed('task_postprocess_end'),

  /// Task was cancelled or killed.
  cancelled('task_cancel'),

  /// A realtime stream is ready.
  streamReady('task_stream_ready'),

  /// A realtime stream ended.
  streamEnded('task_stream_end'),

  /// Status introduced after this SDK version.
  unknown('');

  /// Creates a task status with its wire value.
  const WiroTaskStatus(this.apiValue);

  /// Resolves a Wiro status string without throwing on future values.
  factory WiroTaskStatus.fromApiValue(String value) {
    return values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => unknown,
    );
  }

  /// Status value returned by the Wiro API.
  final String apiValue;

  /// Whether no more polling is required.
  bool get isTerminal => this == completed || this == cancelled;
}

/// A task running on Wiro.
final class WiroTask {
  /// Creates a Wiro task.
  const WiroTask({
    required this.id,
    required this.taskToken,
    required this.parameters,
    required this.status,
    required this.statusValue,
    required this.outputs,
    required this.raw,
    this.exitCode,
    this.debugOutput,
    this.startTime,
    this.endTime,
    this.elapsed,
    this.totalCost,
    this.modelDescription,
    this.modelOwner,
    this.modelSlug,
  });

  /// Creates a task from a Wiro API payload.
  factory WiroTask.fromJson(WiroJson json) {
    final statusValue = JsonReader.string(json['status']) ?? '';
    final outputValue = json['outputs'] ?? json['output'];
    final outputs = JsonReader.list(outputValue)
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroTaskOutput.fromJson)
        .toList(growable: false);

    return WiroTask(
      id: WiroTaskId.tryParse(
        JsonReader.string(json['id']) ?? JsonReader.string(json['taskid']),
      ),
      taskToken: WiroTaskToken.tryParse(
        JsonReader.string(json['socketaccesstoken']),
      ),
      parameters: JsonReader.map(json['parameters']),
      status: WiroTaskStatus.fromApiValue(statusValue),
      statusValue: statusValue,
      exitCode: JsonReader.integerOrNull(json['pexit']),
      debugOutput: JsonReader.string(json['debugoutput']),
      startTime: JsonReader.dateTime(json['starttime']),
      endTime: JsonReader.dateTime(json['endtime']),
      elapsed: _durationFromSeconds(json['elapsedseconds']),
      totalCost: JsonReader.decimal(json['totalcost']),
      outputs: List.unmodifiable(outputs),
      modelDescription: JsonReader.string(json['modeldescription']),
      modelOwner: JsonReader.string(json['modelslugowner']),
      modelSlug: JsonReader.string(json['modelslugproject']),
      raw: Map.unmodifiable(json),
    );
  }

  /// Server-side task identifier, or `null` when Wiro omitted it.
  final WiroTaskId? id;

  /// Token used for polling and subscriptions, or `null` when omitted.
  final WiroTaskToken? taskToken;

  /// Dynamic parameters supplied to the model.
  final WiroJson parameters;

  /// Parsed lifecycle status.
  final WiroTaskStatus status;

  /// Original status value, including values unknown to this SDK version.
  final String statusValue;

  /// Model process exit code. A value of `0` means success.
  final int? exitCode;

  /// Combined model diagnostic output.
  final String? debugOutput;

  /// Server-provided start timestamp.
  final DateTime? startTime;

  /// Server-provided end timestamp.
  final DateTime? endTime;

  /// Total task duration.
  final Duration? elapsed;

  /// Final billed cost.
  final double? totalCost;

  /// Files or structured values produced by the task.
  final List<WiroTaskOutput> outputs;

  /// Model description captured with the task.
  final String? modelDescription;

  /// Model owner captured with the task.
  final String? modelOwner;

  /// Model slug captured with the task.
  final String? modelSlug;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;

  /// Whether the task no longer needs polling.
  bool get isFinished => status.isTerminal;

  /// A completed task succeeds only when its process exit code is `0`.
  bool get isSuccessful {
    return status == WiroTaskStatus.completed && exitCode == 0;
  }
}

Duration? _durationFromSeconds(Object? value) {
  final seconds = JsonReader.decimal(value);
  if (seconds == null || !seconds.isFinite) {
    return null;
  }
  return Duration(milliseconds: (seconds * 1000).round());
}

/// A file or structured value produced by a Wiro task.
final class WiroTaskOutput {
  /// Creates a task output.
  const WiroTaskOutput({
    required this.contentType,
    required this.raw,
    this.name,
    this.size,
    this.url,
    this.content,
  });

  /// Creates a task output from a Wiro payload.
  factory WiroTaskOutput.fromJson(WiroJson json) {
    final contentJson = JsonReader.map(json['content']);
    return WiroTaskOutput(
      name: JsonReader.string(json['name']),
      contentType: JsonReader.string(json['contenttype']) ?? '',
      size: JsonReader.integerOrNull(json['size']),
      url: JsonReader.uri(json['url']),
      content: contentJson.isEmpty
          ? null
          : WiroTaskOutputContent.fromJson(contentJson),
      raw: Map.unmodifiable(json),
    );
  }

  /// Output file name.
  final String? name;

  /// MIME type or Wiro output type.
  final String contentType;

  /// Server-provided output size.
  final int? size;

  /// URL of a generated file.
  final Uri? url;

  /// Structured text output.
  final WiroTaskOutputContent? content;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;

  /// Whether this output contains image media.
  bool get isImage => contentType.toLowerCase().startsWith('image/');

  /// Whether this output contains video media.
  bool get isVideo => contentType.toLowerCase().startsWith('video/');

  /// Whether this output contains audio media.
  bool get isAudio => contentType.toLowerCase().startsWith('audio/');

  /// Whether this output contains text or structured raw text.
  bool get isText {
    final normalized = contentType.toLowerCase();
    return normalized.startsWith('text/') ||
        normalized == 'raw' ||
        normalized == 'application/json';
  }
}

/// Structured output returned by text and language models.
final class WiroTaskOutputContent {
  /// Creates structured task output.
  const WiroTaskOutputContent({
    required this.thinking,
    required this.answers,
    this.prompt,
    this.rawText,
  });

  /// Creates structured output from a Wiro payload.
  factory WiroTaskOutputContent.fromJson(WiroJson json) {
    return WiroTaskOutputContent(
      prompt: JsonReader.string(json['prompt']),
      rawText: JsonReader.string(json['raw']),
      thinking: JsonReader.stringList(json['thinking']),
      answers: JsonReader.stringList(json['answer']),
    );
  }

  /// Original input prompt.
  final String? prompt;

  /// Unstructured model response.
  final String? rawText;

  /// Model reasoning chunks, when provided.
  final List<String> thinking;

  /// Final answer chunks.
  final List<String> answers;
}
