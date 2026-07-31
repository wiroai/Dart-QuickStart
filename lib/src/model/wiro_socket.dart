import 'dart:typed_data';

import 'package:wiro_client/src/model/json_reader.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
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

    return WiroSocketMessageEvent._(
      id: WiroTaskId.tryParse(JsonReader.string(json['id'])),
      taskToken: WiroTaskToken.tryParse(JsonReader.string(json['tasktoken'])),
      status: WiroTaskStatus.fromApiValue(statusValue),
      statusValue: statusValue,
      result: JsonReader.boolean(json['result']),
      payload: WiroSocketPayload.fromValue(statusValue, message),
      raw: Map.unmodifiable(json),
    );
  }

  const WiroSocketMessageEvent._({
    required this.id,
    required this.taskToken,
    required this.status,
    required this.statusValue,
    required this.result,
    required this.payload,
    required this.raw,
  });

  /// Server-side task identifier, or `null` when omitted or invalid.
  final WiroTaskId? id;

  /// Token associated with this task stream, or `null` when omitted.
  final WiroTaskToken? taskToken;

  /// Parsed lifecycle status.
  final WiroTaskStatus status;

  /// Original event type returned by Wiro.
  final String statusValue;

  /// Whether Wiro marked this event as successful.
  final bool result;

  /// Typed event message payload.
  final WiroSocketPayload payload;

  /// Original event payload for forward-compatible access.
  final WiroJson raw;

  /// Plain message text, when [payload] is a [WiroLogPayload].
  String? get messageText {
    return switch (payload) {
      WiroLogPayload(:final message) => message,
      _ => null,
    };
  }

  /// Parsed progress, when [payload] is a [WiroProgressPayload].
  WiroTaskProgress? get progress {
    return switch (payload) {
      WiroProgressPayload(:final progress) => progress,
      _ => null,
    };
  }

  /// Final outputs, when [payload] is a [WiroOutputsPayload].
  List<WiroTaskOutput> get outputs {
    return switch (payload) {
      WiroOutputsPayload(:final outputs) => outputs,
      _ => const [],
    };
  }

  /// Whether this event ends a standard task stream.
  bool get isTerminal => status.isTerminal;
}

/// Base type for typed Wiro WebSocket message payloads.
sealed class WiroSocketPayload {
  const WiroSocketPayload();

  /// Decodes [value] according to the surrounding event [statusValue].
  factory WiroSocketPayload.fromValue(String statusValue, Object? value) {
    if (statusValue == WiroTaskStatus.completed.apiValue) {
      final rawOutputs = JsonReader.list(value);
      final outputs = rawOutputs
          .map(JsonReader.map)
          .where((item) => item.isNotEmpty)
          .map(WiroTaskOutput.fromJson)
          .toList(growable: false);
      return WiroOutputsPayload(
        List.unmodifiable(outputs),
        raw: List.unmodifiable(rawOutputs),
      );
    }
    if (value case final String message) {
      final trimmed = message.trimLeft();
      if (trimmed.startsWith('{')) {
        final messageJson = JsonReader.map(message);
        final hasProgressKey = messageJson.keys.any(_progressKeys.contains);
        if (messageJson.isNotEmpty && hasProgressKey) {
          return WiroProgressPayload(WiroTaskProgress.fromJson(messageJson));
        }
      }
      return WiroLogPayload(message);
    }

    final messageJson = JsonReader.map(value);
    if (messageJson.keys.any(_progressKeys.contains)) {
      return WiroProgressPayload(WiroTaskProgress.fromJson(messageJson));
    }
    return WiroUnknownPayload(value);
  }

  static const _progressKeys = {
    'type',
    'task',
    'percentage',
    'stepCurrent',
    'stepTotal',
    'speed',
    'speedType',
    'elapsedTime',
    'remainingTime',
    'raw',
    'thinking',
    'answer',
    'isThinking',
  };

  /// Original message value for forward-compatible access.
  Object? get raw;
}

/// A plain text message received from a task.
final class WiroLogPayload extends WiroSocketPayload {
  /// Creates a log payload from [message].
  const WiroLogPayload(this.message);

  /// Plain text message.
  final String message;

  @override
  Object get raw => message;
}

/// Structured task progress received from a task.
final class WiroProgressPayload extends WiroSocketPayload {
  /// Creates a progress payload from [progress].
  const WiroProgressPayload(this.progress);

  /// Parsed task progress.
  final WiroTaskProgress progress;

  @override
  Object get raw => progress.raw;
}

/// Final output descriptors received from a task.
final class WiroOutputsPayload extends WiroSocketPayload {
  /// Creates an outputs payload.
  const WiroOutputsPayload(this.outputs, {required this.raw});

  /// Parsed task outputs.
  final List<WiroTaskOutput> outputs;

  @override
  final List<Object?> raw;
}

/// A message payload introduced after this SDK version.
final class WiroUnknownPayload extends WiroSocketPayload {
  /// Creates an unknown payload while preserving [raw].
  const WiroUnknownPayload(this.raw);

  @override
  final Object? raw;
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
