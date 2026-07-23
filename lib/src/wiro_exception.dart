/// Base class for all exceptions produced by the Wiro SDK.
sealed class WiroException implements Exception {
  /// Creates a Wiro exception.
  const WiroException(
    this.message, {
    this.cause,
  });

  /// Human-readable description of the failure.
  final String message;

  /// Original error that caused this exception, when available.
  final Object? cause;

  @override
  String toString() => message;
}

/// Base class for non-successful HTTP responses from the Wiro API.
sealed class WiroApiException extends WiroException {
  /// Creates an API exception.
  const WiroApiException(
    super.message, {
    required this.statusCode,
    required this.responseBody,
    super.cause,
  });

  /// HTTP status code returned by Wiro.
  final int statusCode;

  /// Unmodified response body returned by Wiro.
  final String responseBody;
}

/// Indicates that the supplied Wiro credentials were rejected.
final class WiroAuthenticationException extends WiroApiException {
  /// Creates an authentication exception.
  const WiroAuthenticationException(
    super.message, {
    required super.statusCode,
    required super.responseBody,
  });
}

/// Indicates that Wiro rejected one or more request values.
final class WiroValidationException extends WiroApiException {
  /// Creates a validation exception.
  const WiroValidationException(
    super.message, {
    required super.statusCode,
    required super.responseBody,
  });
}

/// Indicates that the Wiro API rate limit was exceeded.
final class WiroRateLimitException extends WiroApiException {
  /// Creates a rate-limit exception.
  const WiroRateLimitException(
    super.message, {
    required super.statusCode,
    required super.responseBody,
    this.retryAfter,
  });

  /// Suggested delay before retrying the request, when supplied by Wiro.
  final Duration? retryAfter;
}

/// Represents an API response that has no more specific exception type.
final class WiroUnknownApiException extends WiroApiException {
  /// Creates an unknown API exception.
  const WiroUnknownApiException(
    super.message, {
    required super.statusCode,
    required super.responseBody,
    super.cause,
  });
}

/// Indicates that the HTTP request failed before receiving a response.
final class WiroNetworkException extends WiroException {
  /// Creates a network exception.
  const WiroNetworkException(super.message, {super.cause});
}

/// Indicates that a Wiro request exceeded its configured timeout.
final class WiroTimeoutException extends WiroException {
  /// Creates a timeout exception.
  const WiroTimeoutException(
    super.message, {
    required this.timeout,
    super.cause,
  });

  /// Timeout duration that was exceeded.
  final Duration timeout;
}

/// Indicates that a caller explicitly cancelled a Wiro request.
final class WiroRequestCancelledException extends WiroException {
  /// Creates a request-cancelled exception.
  const WiroRequestCancelledException([
    super.message = 'The Wiro request was cancelled.',
  ]);
}
