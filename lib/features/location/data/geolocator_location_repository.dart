import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/models/geo_point.dart';
import '../domain/location_models.dart';
import '../domain/location_repository.dart';

/// [LocationRepository] backed by the `geolocator` plugin.
///
/// On Android it uses the platform `LocationManager` rather than Google Play
/// Services, so location works on devices without Google services.
class GeolocatorLocationRepository implements LocationRepository {
  const GeolocatorLocationRepository();

  static const _fixTimeout = Duration(seconds: 20);

  static final LocationSettings _settings = AndroidSettings(
    forceLocationManager: true,
    distanceFilter: 5,
    intervalDuration: const Duration(seconds: 2),
  );

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationAccess> checkAccess() async =>
      _mapPermission(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestAccess() async {
    try {
      return _mapPermission(await Geolocator.requestPermission());
    } on PermissionRequestInProgressException {
      return LocationAccess.denied;
    }
  }

  @override
  Future<UserPosition> currentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _settings,
      ).timeout(_fixTimeout);
      return _mapPosition(position);
    } catch (error) {
      throw LocationException(_mapError(error));
    }
  }

  @override
  Stream<UserPosition> positionUpdates() =>
      Geolocator.getPositionStream(locationSettings: _settings)
          .map(_mapPosition)
          .handleError(
            (Object error) => throw LocationException(_mapError(error)),
          );

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static LocationAccess _mapPermission(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine => LocationAccess.denied,
      };

  static LocationFailure _mapError(Object error) => switch (error) {
    LocationException(:final failure) => failure,
    LocationServiceDisabledException() => LocationFailure.serviceDisabled,
    PermissionDeniedException() => LocationFailure.permissionDenied,
    _ => LocationFailure.unavailable,
  };

  static UserPosition _mapPosition(Position position) => UserPosition(
    point: GeoPoint(latitude: position.latitude, longitude: position.longitude),
    timestamp: position.timestamp,
    accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
    headingDegrees: position.heading >= 0 && position.speed > 0.5
        ? position.heading
        : null,
  );
}

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => const GeolocatorLocationRepository(),
);
