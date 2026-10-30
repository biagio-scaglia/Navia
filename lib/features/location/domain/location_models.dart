import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

/// A position fix of the device.
@immutable
class UserPosition {
  const UserPosition({
    required this.point,
    required this.timestamp,
    this.accuracyMeters,
    this.headingDegrees,
  });

  final GeoPoint point;
  final DateTime timestamp;

  /// Horizontal accuracy radius, when reported by the device.
  final double? accuracyMeters;

  /// Direction of travel in degrees clockwise from north, when known.
  final double? headingDegrees;

  @override
  bool operator ==(Object other) =>
      other is UserPosition &&
      other.point == point &&
      other.timestamp == timestamp &&
      other.accuracyMeters == accuracyMeters &&
      other.headingDegrees == headingDegrees;

  @override
  int get hashCode =>
      Object.hash(point, timestamp, accuracyMeters, headingDegrees);
}

/// Whether the app may read the device location while in use.
enum LocationAccess {
  granted,
  denied,

  /// The user blocked the request; only the system settings can change it.
  deniedForever,
}

/// Reasons why the device location could not be obtained.
enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,

  /// No fix was obtained in time, or the platform reported an error.
  unavailable,
}

class LocationException implements Exception {
  const LocationException(this.failure);

  final LocationFailure failure;

  @override
  String toString() => 'LocationException($failure)';
}
