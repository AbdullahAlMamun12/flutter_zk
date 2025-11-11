// lib/src/exceptions.dart

class ZKError implements Exception {
  final String message;
  ZKError(this.message);

  @override
  String toString() => 'ZKError: $message';
}

class ZKErrorConnection extends ZKError {
  ZKErrorConnection(super.message);
}

class ZKErrorResponse extends ZKError {
  ZKErrorResponse(super.message);
}

class ZKNetworkError extends ZKError {
  ZKNetworkError(super.message);
}
