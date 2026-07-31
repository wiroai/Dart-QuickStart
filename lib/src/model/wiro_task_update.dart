import 'dart:typed_data';

import 'package:wiro_client/src/model/wiro_socket.dart';
import 'package:wiro_client/src/model/wiro_task.dart';

/// Transport used by `WiroClient.subscribe` to track a submitted task.
enum WiroTaskTrackingMode {
  /// Periodically requests the task detail endpoint.
  polling,

  /// Receives realtime task events over WebSocket.
  webSocket,
}

/// A normalized task update produced by polling or WebSocket tracking.
sealed class WiroTaskUpdate {
  const WiroTaskUpdate({required this.status, required this.statusValue});

  /// Creates an update from a polled task snapshot.
  factory WiroTaskUpdate.fromTask(WiroTask task) = WiroTaskSnapshotUpdate;

  /// Creates an update from a WebSocket event.
  factory WiroTaskUpdate.fromSocketEvent(WiroSocketEvent event) {
    return switch (event) {
      WiroSocketMessageEvent() => WiroTaskEventUpdate(event),
      WiroSocketBinaryEvent(:final bytes) => WiroTaskBinaryUpdate._(bytes),
    };
  }

  /// Parsed lifecycle status.
  final WiroTaskStatus status;

  /// Original status or frame type.
  final String statusValue;

  /// Whether this update represents the end of a standard task.
  bool get isTerminal => status.isTerminal;
}

/// A complete task snapshot produced by polling.
final class WiroTaskSnapshotUpdate extends WiroTaskUpdate {
  /// Creates an update from a non-nullable task [task].
  WiroTaskSnapshotUpdate(this.task)
    : super(status: task.status, statusValue: task.statusValue);

  /// Polled task snapshot.
  final WiroTask task;
}

/// A typed JSON event produced by WebSocket tracking.
final class WiroTaskEventUpdate extends WiroTaskUpdate {
  /// Creates an update from a non-nullable socket [event].
  WiroTaskEventUpdate(this.event)
    : super(status: event.status, statusValue: event.statusValue);

  /// Original typed WebSocket event.
  final WiroSocketMessageEvent event;
}

/// A binary frame produced by WebSocket tracking.
final class WiroTaskBinaryUpdate extends WiroTaskUpdate {
  /// Creates a binary update by copying [bytes].
  WiroTaskBinaryUpdate(List<int> bytes)
    : bytes = Uint8List.fromList(bytes),
      super(status: WiroTaskStatus.unknown, statusValue: 'binary');

  WiroTaskBinaryUpdate._(this.bytes)
    : super(status: WiroTaskStatus.unknown, statusValue: 'binary');

  /// Raw binary frame bytes.
  final Uint8List bytes;
}

/// Receives normalized polling or WebSocket task updates.
typedef WiroTaskUpdateCallback = void Function(WiroTaskUpdate update);
