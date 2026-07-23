import 'dart:typed_data';

import 'package:wiro_client/src/model/json_reader.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_task.dart';

/// Base type for messages received from a Wiro task WebSocket.
sealed class WiroSocketEvent {
  const WiroSocketEvent();
}

/// A JSON task lifecycle or output event received over WebSocket.
final class WiroSocketMessageEvent extends WiroSocketEvent {
  /// Creates a typed socket message from a Wiro payload.
  factory WiroSocketMessageEvent.fromJson(WiroJson json) {
    final statusValue = JsonReader.string(json['type']) ?? '';
    final message = json['message'];
    final messageJson = JsonReader.map(message);
    final outputValues = statusValue == 'task_postprocess_end'
        ? JsonReader.list(message)
        : const <Object?>[];

    return WiroSocketMessageEvent._(
      id: JsonReader.string(json['id']) ?? '',
      taskToken: JsonReader.string(json['tasktoken']) ?? '',
      status: WiroTaskStatus.fromApiValue(statusValue),
      statusValue: statusValue,
      result: JsonReader.boolean(json['result']),
      message: message,
      progress: messageJson.isEmpty
          ? null
          : WiroTaskProgress.fromJson(messageJson),
      outputs: List.unmodifiable(
        outputValues
            .map(JsonReader.map)
            .where((item) => item.isNotEmpty)
            .map(WiroTaskOutput.fromJson),
      ),
      raw: Map.unmodifiable(json),
    );
  }

  const WiroSocketMessageEvent._({
    required this.id,
    required this.taskToken,
    required this.status,
    required this.statusValue,
    required this.result,
    required this.message,
    required this.progress,
    required this.outputs,
    required this.raw,
  });

  /// Server-side task identifier.
  final String id;

  /// Token associated with this task stream.
  final String taskToken;

  /// Parsed lifecycle status.
  final WiroTaskStatus status;

  /// Original event type returned by Wiro.
  final String statusValue;

  /// Whether Wiro marked this event as successful.
  final bool result;

  /// Dynamic event payload.
  final Object? message;

  /// Parsed progress or structured text payload, when available.
  final WiroTaskProgress? progress;

  /// Final task outputs supplied by `task_postprocess_end`.
  final List<WiroTaskOutput> outputs;

  /// Original event payload for forward-compatible access.
  final WiroJson raw;

  /// Plain message text, when [message] is a string.
  String? get messageText => JsonReader.string(message);

  /// Whether this event ends a standard task stream.
  bool get isTerminal => status.isTerminal;
}

/// A binary frame received from a realtime Wiro task.
final class WiroSocketBinaryEvent extends WiroSocketEvent {
  /// Creates a binary socket event.
  WiroSocketBinaryEvent(List<int> bytes) : bytes = Uint8List.fromList(bytes);

  /// Raw frame bytes.
  final Uint8List bytes;
}

/// Structured progress or language-model output carried by a socket event.
final class WiroTaskProgress {
  /// Creates progress data from a Wiro socket message.
  factory WiroTaskProgress.fromJson(WiroJson json) {
    return WiroTaskProgress._(
      type: JsonReader.string(json['type']),
      task: JsonReader.string(json['task']),
      percentage: JsonReader.decimal(json['percentage']),
      currentStep: JsonReader.integer(json['stepCurrent']),
      totalSteps: JsonReader.integer(json['stepTotal']),
      speed: JsonReader.string(json['speed']),
      speedType: JsonReader.string(json['speedType']),
      elapsedTime: JsonReader.string(json['elapsedTime']),
      remainingTime: JsonReader.string(json['remainingTime']),
      rawText: JsonReader.string(json['raw']),
      thinking: JsonReader.stringList(json['thinking']),
      answers: JsonReader.stringList(json['answer']),
      isThinking: JsonReader.boolean(json['isThinking']),
      raw: Map.unmodifiable(json),
    );
  }

  const WiroTaskProgress._({
    required this.type,
    required this.task,
    required this.percentage,
    required this.currentStep,
    required this.totalSteps,
    required this.speed,
    required this.speedType,
    required this.elapsedTime,
    required this.remainingTime,
    required this.rawText,
    required this.thinking,
    required this.answers,
    required this.isThinking,
    required this.raw,
  });

  /// Progress payload type.
  final String? type;

  /// Human-readable task phase.
  final String? task;

  /// Completion percentage.
  final double? percentage;

  /// Current generation step, or zero when omitted.
  final int currentStep;

  /// Total generation steps, or zero when omitted.
  final int totalSteps;

  /// Current generation speed.
  final String? speed;

  /// Unit associated with [speed].
  final String? speedType;

  /// Server-formatted elapsed duration.
  final String? elapsedTime;

  /// Server-formatted estimated remaining duration.
  final String? remainingTime;

  /// Complete accumulated raw output.
  final String? rawText;

  /// Accumulated language-model reasoning chunks.
  final List<String> thinking;

  /// Accumulated language-model answer chunks.
  final List<String> answers;

  /// Whether a language model is currently producing reasoning.
  final bool isThinking;

  /// Original progress payload for forward-compatible access.
  final WiroJson raw;
}
