import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../shared/models/geo_bounds.dart';
import '../domain/map_style_source.dart';

/// The active map style provider. Override to use another tile provider.
final mapStyleSourceProvider = Provider<MapStyleSource>(
  (ref) => AppConfig.mapStyleSource,
);

/// Delay after which a style that has not loaded is treated as a failure.
final mapLoadTimeoutProvider = Provider<Duration>(
  (ref) => AppConfig.mapLoadTimeout,
);

/// Camera bearing in degrees clockwise from north, followed while the
/// camera moves, for Navia's own compass.
class MapBearing extends Notifier<double> {
  @override
  double build() => 0;

  /// Ignores changes under half a degree, which would only rebuild the
  /// compass on every frame of a pan.
  void update(double bearing) {
    if (bearing == 0 || (bearing - state).abs() >= 0.5) state = bearing;
  }

  /// How far the map is turned from north, from 0 to 180 degrees.
  static double offNorth(double bearing) {
    final b = bearing % 360;
    return b > 180 ? 360 - b : b;
  }
}

final mapBearingProvider = NotifierProvider<MapBearing, double>(MapBearing.new);

/// The visible area and zoom once the camera stops; null before the first
/// stop.
class MapViewport extends Notifier<({GeoBounds bounds, double zoom})?> {
  @override
  ({GeoBounds bounds, double zoom})? build() => null;

  void changed(GeoBounds bounds, double zoom) =>
      state = (bounds: bounds, zoom: zoom);
}

final mapViewportProvider =
    NotifierProvider<MapViewport, ({GeoBounds bounds, double zoom})?>(
      MapViewport.new,
    );

enum MapLoadStatus { loading, ready, failed }

@immutable
class MapLoadState {
  const MapLoadState({
    this.status = MapLoadStatus.loading,
    this.attempt = 0,
    this.hasLoaded = false,
  });

  final MapLoadStatus status;

  /// Incremented on every retry, used to recreate the map view.
  final int attempt;

  /// Whether a style has loaded at least once in this session.
  final bool hasLoaded;

  MapLoadState copyWith({
    MapLoadStatus? status,
    int? attempt,
    bool? hasLoaded,
  }) {
    return MapLoadState(
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MapLoadState &&
      other.status == status &&
      other.attempt == attempt &&
      other.hasLoaded == hasLoaded;

  @override
  int get hashCode => Object.hash(status, attempt, hasLoaded);
}

/// Tracks style loading. The MapLibre plugin reports no style errors, so a
/// failure is either a platform initialization error or a timeout.
class MapLoadController extends Notifier<MapLoadState> {
  Timer? _timeout;

  @override
  MapLoadState build() {
    ref.onDispose(() => _timeout?.cancel());
    return const MapLoadState();
  }

  /// Called whenever the map starts loading a style.
  void loadStarted() {
    _timeout?.cancel();
    _timeout = Timer(ref.read(mapLoadTimeoutProvider), failed);
    state = state.copyWith(status: MapLoadStatus.loading);
  }

  void styleLoaded() {
    _timeout?.cancel();
    state = state.copyWith(status: MapLoadStatus.ready, hasLoaded: true);
  }

  void failed() {
    _timeout?.cancel();
    if (state.status == MapLoadStatus.ready) return;
    state = state.copyWith(status: MapLoadStatus.failed);
  }

  /// Recreates the map view and starts a new loading attempt.
  void retry() {
    _timeout?.cancel();
    state = state.copyWith(
      status: MapLoadStatus.loading,
      attempt: state.attempt + 1,
    );
  }
}

final mapLoadControllerProvider =
    NotifierProvider<MapLoadController, MapLoadState>(MapLoadController.new);
