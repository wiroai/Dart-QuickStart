import 'dart:typed_data';

import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/model/wiro_socket.dart';
import 'package:wiro_client/src/model/wiro_task.dart';

/// Transport used by `WiroClient.subscribe` to track a submitted task.
enum WiroTaskTrackingMode {
  /// Periodically requests the task detail endpoint.
  polling,

  /// Receives realtime task events over WebSocket.
  webSocket,
}

/// Source that produced a [WiroTaskUpdate].
enum WiroTaskUpdateSource {
  /// Update created from a task detail response.
  polling,

  /// Update created from a WebSocket frame.
  webSocket,
}

/// A normalized task update produced by polling or WebSocket tracking.
final class WiroTaskUpdate {
  /// Creates an update from a polled task snapshot.
  factory WiroTaskUpdate.fromTask(WiroTask task) {
    return WiroTaskUpdate._(
      source: WiroTaskUpdateSource.polling,
      id: task.id,
      taskToken: task.taskToken,
      status: task.status,
      statusValue: task.statusValue,
      result: task.isFinished ? task.isSuccessful : null,
      message: task.debugOutput,
      progress: null,
      outputs: task.outputs,
      binaryData: null,
      task: task,
      socketEvent: null,
      raw: task.raw,
    );
  }

  /// Creates an update from a WebSocket event.
  factory WiroTaskUpdate.fromSocketEvent(WiroSocketEvent event) {
    return switch (event) {
      WiroSocketMessageEvent(
        :final id,
        :final taskToken,
        :final status,
        :final statusValue,
        :final result,
        :final message,
        :final progress,
        :final outputs,
        :final raw,
      ) =>
        WiroTaskUpdate._(
          source: WiroTaskUpdateSource.webSocket,
          id: id,
          taskToken: taskToken,
          status: status,
          statusValue: statusValue,
          result: result,
          message: message,
          progress: progress,
          outputs: outputs,
          binaryData: null,
          task: null,
          socketEvent: event,
          raw: raw,
        ),
      WiroSocketBinaryEvent(:final bytes) => WiroTaskUpdate._(
        source: WiroTaskUpdateSource.webSocket,
        id: '',
        taskToken: '',
        status: WiroTaskStatus.unknown,
        statusValue: 'binary',
        result: null,
        message: null,
        progress: null,
        outputs: const [],
        binaryData: bytes,
        task: null,
        socketEvent: event,
        raw: const {},
      ),
    };
  }

  const WiroTaskUpdate._({
    required this.source,
    required this.id,
    required this.taskToken,
    required this.status,
    required this.statusValue,
    required this.result,
    required this.message,
    required this.progress,
    required this.outputs,
    required this.binaryData,
    required this.task,
    required this.socketEvent,
    required this.raw,
  });

  /// Transport that produced this update.
  final WiroTaskUpdateSource source;

  /// Server-side task identifier, when supplied.
  final String id;

  /// Task token, when supplied.
  final String taskToken;

  /// Parsed lifecycle status.
  final WiroTaskStatus status;

  /// Original status or frame type.
  final String statusValue;

  /// Success value reported by the current update, when available.
  final bool? result;

  /// Dynamic progress, output, or diagnostic payload.
  final Object? message;

  /// Parsed progress data for compatible WebSocket events.
  final WiroTaskProgress? progress;

  /// Outputs supplied by the current update.
  final List<WiroTaskOutput> outputs;

  /// Binary realtime payload, when this update represents a binary frame.
  final Uint8List? binaryData;

  /// Full task snapshot for polling updates.
  final WiroTask? task;

  /// Original socket event for WebSocket updates.
  final WiroSocketEvent? socketEvent;

  /// Original JSON payload for forward-compatible access.
  final WiroJson raw;

  /// Whether this update represents the end of a standard task.
  bool get isTerminal => status.isTerminal;
}

/// Receives normalized polling or WebSocket task updates.
typedef WiroTaskUpdateCallback = void Function(WiroTaskUpdate update);
