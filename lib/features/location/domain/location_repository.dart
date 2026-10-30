import 'location_models.dart';

/// Access to the device location.
///
/// Implementations only read the location while the app is in use and never
/// store or transmit it.
abstract interface class LocationRepository {
  Future<bool> isServiceEnabled();

  Future<LocationAccess> checkAccess();

  /// Shows the system permission dialog when the platform allows it.
  Future<LocationAccess> requestAccess();

  /// A single fresh fix. Throws [LocationException] on failure.
  Future<UserPosition> currentPosition();

  /// Continuous foreground updates. Emits [LocationException] errors.
  Stream<UserPosition> positionUpdates();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
