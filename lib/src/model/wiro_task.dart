import 'package:wiro_ai/src/model/json_reader.dart';
import 'package:wiro_ai/src/model/wiro_json.dart';

/// Lifecycle state of a Wiro task.
enum WiroTaskStatus {
  queued('task_queue'),
  accepted('task_accept'),
  preprocessing('task_preprocess_start'),
  preprocessed('task_preprocess_end'),
  assigned('task_assign'),
  running('task_start'),
  output('task_output'),
  outputComplete('task_output_full'),
  errorOutput('task_error'),
  errorOutputComplete('task_error_full'),
  processEnded('task_end'),
  postProcessing('task_postprocess_start'),
  completed('task_postprocess_end'),
  cancelled('task_cancel'),
  streamReady('task_stream_ready'),
  streamEnded('task_stream_end'),
  unknown('');

  const WiroTaskStatus(this.apiValue);

  factory WiroTaskStatus.fromApiValue(String value) {
    return values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => unknown,
    );
  }

  final String apiValue;

  /// Whether no more polling is required.
  bool get isTerminal => this == completed || this == cancelled;
}

/// A task running on Wiro.
final class WiroTask {
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
    this.elapsedSeconds,
    this.totalCost,
    this.modelDescription,
    this.modelOwner,
    this.modelSlug,
  });

  factory WiroTask.fromJson(WiroJson json) {
    final statusValue = JsonReader.string(json['status']) ?? '';
    final outputValue = json['outputs'] ?? json['output'];
    final outputs = JsonReader.list(outputValue)
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroTaskOutput.fromJson)
        .toList(growable: false);

    return WiroTask(
      id:
          JsonReader.string(json['id']) ??
          JsonReader.string(json['taskid']) ??
          '',
      taskToken: JsonReader.string(json['socketaccesstoken']) ?? '',
      parameters: JsonReader.map(json['parameters']),
      status: WiroTaskStatus.fromApiValue(statusValue),
      statusValue: statusValue,
      exitCode: JsonReader.string(json['pexit']),
      debugOutput: JsonReader.string(json['debugoutput']),
      startTime: JsonReader.string(json['starttime']),
      endTime: JsonReader.string(json['endtime']),
      elapsedSeconds: JsonReader.decimal(json['elapsedseconds']),
      totalCost: JsonReader.decimal(json['totalcost']),
      outputs: List.unmodifiable(outputs),
      modelDescription: JsonReader.string(json['modeldescription']),
      modelOwner: JsonReader.string(json['modelslugowner']),
      modelSlug: JsonReader.string(json['modelslugproject']),
      raw: Map.unmodifiable(json),
    );
  }

  final String id;
  final String taskToken;
  final WiroJson parameters;
  final WiroTaskStatus status;

  /// Original status value, including values unknown to this SDK version.
  final String statusValue;

  final String? exitCode;
  final String? debugOutput;
  final String? startTime;
  final String? endTime;
  final double? elapsedSeconds;
  final double? totalCost;
  final List<WiroTaskOutput> outputs;
  final String? modelDescription;
  final String? modelOwner;
  final String? modelSlug;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;

  bool get isFinished => status.isTerminal;

  /// A completed task succeeds only when its process exit code is `0`.
  bool get isSuccessful {
    return status == WiroTaskStatus.completed && exitCode == '0';
  }
}

/// A file or structured value produced by a Wiro task.
final class WiroTaskOutput {
  const WiroTaskOutput({
    required this.contentType,
    required this.raw,
    this.name,
    this.size,
    this.url,
    this.content,
  });

  factory WiroTaskOutput.fromJson(WiroJson json) {
    final contentJson = JsonReader.map(json['content']);
    return WiroTaskOutput(
      name: JsonReader.string(json['name']),
      contentType: JsonReader.string(json['contenttype']) ?? '',
      size: JsonReader.string(json['size']),
      url: JsonReader.uri(json['url']),
      content: contentJson.isEmpty
          ? null
          : WiroTaskOutputContent.fromJson(contentJson),
      raw: Map.unmodifiable(json),
    );
  }

  final String? name;
  final String contentType;
  final String? size;
  final Uri? url;
  final WiroTaskOutputContent? content;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// Structured output returned by text and language models.
final class WiroTaskOutputContent {
  const WiroTaskOutputContent({
    required this.thinking,
    required this.answers,
    this.prompt,
    this.rawText,
  });

  factory WiroTaskOutputContent.fromJson(WiroJson json) {
    return WiroTaskOutputContent(
      prompt: JsonReader.string(json['prompt']),
      rawText: JsonReader.string(json['raw']),
      thinking: JsonReader.stringList(json['thinking']),
      answers: JsonReader.stringList(json['answer']),
    );
  }

  final String? prompt;
  final String? rawText;
  final List<String> thinking;
  final List<String> answers;
}
