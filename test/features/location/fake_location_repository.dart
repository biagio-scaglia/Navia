import 'dart:async';

import 'package:navia/features/location/domain/location_models.dart';
import 'package:navia/features/location/domain/location_repository.dart';

/// Scriptable [LocationRepository] for tests.
class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository({
    this.serviceEnabled = true,
    this.access = LocationAccess.granted,
    this.accessAfterRequest = LocationAccess.granted,
    this.position,
    this.positionFailure,
  });

  bool serviceEnabled;
  LocationAccess access;
  LocationAccess accessAfterRequest;
  UserPosition? position;
  LocationFailure? positionFailure;

  int requestCount = 0;
  int currentPositionCount = 0;
  final List<String> openedSettings = [];
  final StreamController<UserPosition> updates =
      StreamController<UserPosition>.broadcast();

  Future<void> close() => updates.close();

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationAccess> checkAccess() async => access;

  @override
  Future<LocationAccess> requestAccess() async {
    requestCount++;
    access = accessAfterRequest;
    return access;
  }

  @override
  Future<UserPosition> currentPosition() async {
    currentPositionCount++;
    final failure = positionFailure;
    if (failure != null) throw LocationException(failure);
    return position!;
  }

  @override
  Stream<UserPosition> positionUpdates() => updates.stream;

  @override
  Future<bool> openAppSettings() async {
    openedSettings.add('app');
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openedSettings.add('location');
    return true;
  }
}
