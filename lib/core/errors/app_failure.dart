/// Failures of online services, shared by search and routing.
enum ServiceFailure {
  /// The device has no usable network connection.
  noConnection,

  /// The service did not answer in time.
  timeout,

  /// The service answered with a server error or is not reachable.
  unavailable,

  /// The service rejected the request because of too many requests.
  rateLimited,

  /// The response could not be understood.
  malformedResponse,

  /// The input could not be processed, e.g. invalid coordinates.
  invalidRequest,

  /// The service is not configured in this build.
  notConfigured,
}

class ServiceException implements Exception {
  const ServiceException(this.failure, [this.cause]);

  final ServiceFailure failure;

  /// Underlying error, for logs only. Never shown to users.
  final Object? cause;

  @override
  String toString() => 'ServiceException($failure, $cause)';
}
