import 'dart:async';
import 'dart:math' as math;

import 'package:wiro_client/src/wiro_exception.dart';

/// Allows a caller to cancel an in-flight Wiro request.
final class WiroCancellationToken {
  final Completer<void> _completer = Completer<void>();

  /// Whether cancellation has already been requested.
  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _completer.future;

  /// Cancels requests using this token.
  void cancel() {
    if (!isCancelled) {
      _completer.complete();
    }
  }

  /// Throws when this token has been cancelled.
  void throwIfCancelled() {
    if (isCancelled) {
      throw const WiroRequestCancelledException();
    }
  }
}

/// Defines retry behavior for transient failures on safe Wiro operations.
///
/// The client does not apply this policy to model runs or file uploads.
final class WiroRetryPolicy {
  /// Creates a retry policy.
  const WiroRetryPolicy({
    this.maxRetries = 2,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maximumDelay = const Duration(seconds: 4),
    this.multiplier = 2,
    this.statusCodes = const {408, 429, 500, 502, 503, 504},
  }) : assert(maxRetries >= 0, 'maxRetries cannot be negative'),
       assert(multiplier >= 1, 'multiplier must be at least 1');

  /// Disables automatic retries.
  const WiroRetryPolicy.none()
    : maxRetries = 0,
      initialDelay = Duration.zero,
      maximumDelay = Duration.zero,
      multiplier = 1,
      statusCodes = const {};

  /// Maximum number of retries after the initial request.
  final int maxRetries;

  /// Delay before the first retry.
  final Duration initialDelay;

  /// Upper bound for a computed retry delay.
  final Duration maximumDelay;

  /// Exponential multiplier applied after each retry.
  final double multiplier;

  /// HTTP status codes considered transient.
  final Set<int> statusCodes;

  /// Returns the delay before retry number [retryIndex].
  Duration delayFor(int retryIndex) {
    final factor = math.pow(multiplier, retryIndex).toDouble();
    final milliseconds = initialDelay.inMilliseconds * factor;
    return Duration(
      milliseconds: math.min(
        milliseconds.round(),
        maximumDelay.inMilliseconds,
      ),
    );
  }

  /// Whether [statusCode] should be retried.
  bool shouldRetryStatus(int statusCode) => statusCodes.contains(statusCode);
}

/// Severity of a [WiroLogEvent].
enum WiroLogLevel {
  /// Detailed SDK diagnostics.
  debug,

  /// Normal request lifecycle information.
  info,

  /// A recoverable condition such as a retry.
  warning,

  /// A request that ultimately failed.
  error,
}

/// Structured, credential-free diagnostic event emitted by the SDK.
final class WiroLogEvent {
  /// Creates a log event.
  const WiroLogEvent({
    required this.level,
    required this.message,
    this.method,
    this.uri,
    this.statusCode,
    this.duration,
    this.retryCount,
    this.error,
  });

  /// Event severity.
  final WiroLogLevel level;

  /// Human-readable event description.
  final String message;

  /// HTTP method associated with the event.
  final String? method;

  /// Request URI. Credentials and request data are never included.
  final Uri? uri;

  /// Response status code, when available.
  final int? statusCode;

  /// Time spent on the request attempt.
  final Duration? duration;

  /// Zero-based retry count, when this is a retry event.
  final int? retryCount;

  /// Associated error, when available.
  final Object? error;
}

/// Receives structured Wiro SDK log events.
typedef WiroLogger = void Function(WiroLogEvent event);
