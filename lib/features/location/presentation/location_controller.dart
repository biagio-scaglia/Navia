import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geolocator_location_repository.dart';
import '../domain/location_models.dart';
import '../domain/location_repository.dart';

enum LocationStatus { idle, locating, tracking, failed }

@immutable
class LocationState {
  const LocationState({
    this.status = LocationStatus.idle,
    this.position,
    this.failure,
  });

  final LocationStatus status;

  /// Latest known fix. Only available while [status] is tracking.
  final UserPosition? position;

  /// Why the last activation failed, when [status] is failed.
  final LocationFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is LocationState &&
      other.status == status &&
      other.position == position &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, position, failure);
}

/// Drives the device location feature.
///
/// Location is never requested automatically: it is activated only through
/// [locate], which is triggered by an explicit user action. Positions are
/// kept in memory only and updates stop while the app is in background.
class LocationController extends Notifier<LocationState> {
  StreamSubscription<UserPosition>? _subscription;
  bool _paused = false;

  LocationRepository get _repository => ref.read(locationRepositoryProvider);

  @override
  LocationState build() {
    ref.onDispose(_stopUpdates);
    return const LocationState();
  }

  /// Activates location if needed and returns the current fix.
  ///
  /// Returns null on failure; the reason is exposed through the state.
  Future<UserPosition?> locate() async {
    final current = state;
    if (current.status == LocationStatus.locating) return null;
    if (current.status == LocationStatus.tracking && current.position != null) {
      return current.position;
    }

    state = const LocationState(status: LocationStatus.locating);
    try {
      await _ensureAccess();
      final position = await _repository.currentPosition();
      if (!ref.mounted) return null;
      state = LocationState(
        status: LocationStatus.tracking,
        position: position,
      );
      _startUpdates();
      return position;
    } on LocationException catch (error) {
      if (ref.mounted) _fail(error.failure);
      return null;
    }
  }

  /// Stops position updates, e.g. when the app goes to background.
  void pause() {
    _paused = true;
    _stopUpdates();
  }

  /// Restarts position updates stopped by [pause].
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (state.status == LocationStatus.tracking) _startUpdates();
  }

  /// Opens the system screen that can resolve [failure].
  Future<bool> openSettingsFor(LocationFailure failure) =>
      failure == LocationFailure.serviceDisabled
      ? _repository.openLocationSettings()
      : _repository.openAppSettings();

  Future<void> _ensureAccess() async {
    if (!await _repository.isServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }
    var access = await _repository.checkAccess();
    if (access == LocationAccess.denied) {
      access = await _repository.requestAccess();
    }
    switch (access) {
      case LocationAccess.granted:
        return;
      case LocationAccess.denied:
        throw const LocationException(LocationFailure.permissionDenied);
      case LocationAccess.deniedForever:
        throw const LocationException(LocationFailure.permissionDeniedForever);
    }
  }

  void _startUpdates() {
    _stopUpdates();
    _subscription = _repository.positionUpdates().listen(
      (position) => state = LocationState(
        status: LocationStatus.tracking,
        position: position,
      ),
      onError: (Object error) {
        _stopUpdates();
        _fail(
          error is LocationException
              ? error.failure
              : LocationFailure.unavailable,
        );
      },
    );
  }

  void _stopUpdates() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _fail(LocationFailure failure) {
    state = LocationState(status: LocationStatus.failed, failure: failure);
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

/// Current permission state, used to inform the user in the settings.
final locationAccessProvider = FutureProvider.autoDispose<LocationAccess>(
  (ref) => ref.watch(locationRepositoryProvider).checkAccess(),
);
