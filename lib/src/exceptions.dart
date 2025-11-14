// lib/src/exceptions.dart

/// Base class for all ZKTeco device-related exceptions.
class ZKError implements Exception {
  /// A message describing the error.
  final String message;

  /// Creates a new [ZKError] with the given [message].
  ZKError(this.message);

  @override
  String toString() => 'ZKError: $message';
}

/// An exception thrown when there is a connection error with the device.
class ZKErrorConnection extends ZKError {
  /// Creates a new [ZKErrorConnection] with the given [message].
  ZKErrorConnection(super.message);
}

/// An exception thrown when the device returns an unexpected or error response.
class ZKErrorResponse extends ZKError {
  /// Creates a new [ZKErrorResponse] with the given [message].
  ZKErrorResponse(super.message);
}

/// An exception thrown for network-related errors during communication.
class ZKNetworkError extends ZKError {
  /// Creates a new [ZKNetworkError] with the given [message].
  ZKNetworkError(super.message);
}
