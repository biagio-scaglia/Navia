import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_point.dart';
import '../../location/domain/location_models.dart';
import '../../location/presentation/location_controller.dart';
import '../../search/data/photon_geocoding_repository.dart';
import '../data/osrm_routing_repository.dart';
import '../domain/navigation_models.dart';

enum RouteStatus { idle, loading, ready, failed }

/// Progress of the address lookup for a point picked on the map.
enum SelectionLookup { idle, loading, failed }

/// Why a route could not be shown.
sealed class RouteError {
  const RouteError();
}

final class RouteServiceError extends RouteError {
  const RouteServiceError(this.failure);
  final ServiceFailure failure;

  @override
  bool operator ==(Object other) =>
      other is RouteServiceError && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

/// The current location was requested as origin but is not available.
final class RouteLocationError extends RouteError {
  const RouteLocationError(this.failure);
  final LocationFailure failure;

  @override
  bool operator ==(Object other) =>
      other is RouteLocationError && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}

final class RouteSamePointsError extends RouteError {
  const RouteSamePointsError();

  @override
  bool operator ==(Object other) => other is RouteSamePointsError;

  @override
  int get hashCode => (RouteSamePointsError).hashCode;
}

@immutable
class NavigationState {
  const NavigationState({
    this.selection,
    this.selectionLookup = SelectionLookup.idle,
    this.origin,
    this.destination,
    this.mode = TravelMode.driving,
    this.routeStatus = RouteStatus.idle,
    this.route,
    this.error,
  });

  /// A point picked on the map or in search, not yet used in a route.
  final PointWaypoint? selection;

  final SelectionLookup selectionLookup;

  final Waypoint? origin;
  final Waypoint? destination;
  final TravelMode mode;
  final RouteStatus routeStatus;

  /// The route for the current origin, destination and mode.
  final NavRoute? route;

  final RouteError? error;

  bool get canCalculate =>
      origin != null &&
      destination != null &&
      routeStatus != RouteStatus.loading;

  /// Whether the user started planning a route.
  bool get isPlanning => origin != null || destination != null;

  NavigationState copyWith({
    PointWaypoint? Function()? selection,
    SelectionLookup? selectionLookup,
    Waypoint? Function()? origin,
    Waypoint? Function()? destination,
    TravelMode? mode,
    RouteStatus? routeStatus,
    NavRoute? Function()? route,
    RouteError? Function()? error,
  }) {
    return NavigationState(
      selection: selection == null ? this.selection : selection(),
      selectionLookup: selectionLookup ?? this.selectionLookup,
      origin: origin == null ? this.origin : origin(),
      destination: destination == null ? this.destination : destination(),
      mode: mode ?? this.mode,
      routeStatus: routeStatus ?? this.routeStatus,
      route: route == null ? this.route : route(),
      error: error == null ? this.error : error(),
    );
  }
}

/// Plans a route from origin to destination.
///
/// Changing origin or destination discards the current route; it is then
/// recalculated only on request, so no network call happens while the user
/// is still editing. Changing the travel mode recalculates a shown route.
class NavigationController extends Notifier<NavigationState> {
  int _generation = 0;
  int _selectionGeneration = 0;

  @override
  NavigationState build() {
    final modes = supportedModes;
    return NavigationState(
      mode: modes.contains(TravelMode.driving)
          ? TravelMode.driving
          : (modes.isEmpty ? TravelMode.driving : modes.first),
    );
  }

  Set<TravelMode> get supportedModes =>
      ref.read(routingRepositoryProvider).supportedModes;

  void select(PointWaypoint waypoint) => _setSelection(waypoint);

  void clearSelection() => _setSelection(null);

  /// Selects a point picked on the map and looks up its address.
  ///
  /// The point itself is kept as picked; the address only labels it. A
  /// failed lookup leaves the coordinates usable.
  Future<void> selectPoint(GeoPoint point) async {
    final generation = _setSelection(PointWaypoint(point));
    final geocoder = ref.read(geocodingRepositoryProvider);
    if (geocoder == null) return;
    state = state.copyWith(selectionLookup: SelectionLookup.loading);
    try {
      final place = await geocoder.reverse(point);
      if (!ref.mounted || generation != _selectionGeneration) return;
      state = state.copyWith(
        selection: () => place == null
            ? PointWaypoint(point)
            : PointWaypoint(
                point,
                label: place.name,
                description: place.description,
                category: place.category,
              ),
        selectionLookup: SelectionLookup.idle,
      );
    } on ServiceException catch (error) {
      logServiceError('reverse geocoding', error);
      if (!ref.mounted || generation != _selectionGeneration) return;
      state = state.copyWith(selectionLookup: SelectionLookup.failed);
    }
  }

  /// Replaces the selection and invalidates pending lookups.
  int _setSelection(PointWaypoint? waypoint) {
    state = state.copyWith(
      selection: () => waypoint,
      selectionLookup: SelectionLookup.idle,
    );
    return ++_selectionGeneration;
  }

  void useSelectionAsOrigin() {
    final selection = state.selection;
    if (selection == null) return;
    _updateWaypoints(origin: selection, destination: state.destination);
  }

  void useSelectionAsDestination() {
    final selection = state.selection;
    if (selection == null) return;
    // Starting from the user location is the most common case.
    _updateWaypoints(
      origin: state.origin ?? const CurrentLocationWaypoint(),
      destination: selection,
    );
  }

  void setOrigin(Waypoint? origin) =>
      _updateWaypoints(origin: origin, destination: state.destination);

  void setDestination(Waypoint? destination) =>
      _updateWaypoints(origin: state.origin, destination: destination);

  void swap() {
    final hadRoute = state.routeStatus == RouteStatus.ready;
    _updateWaypoints(origin: state.destination, destination: state.origin);
    if (hadRoute) unawaited(calculate());
  }

  Future<void> setMode(TravelMode mode) async {
    if (mode == state.mode || !supportedModes.contains(mode)) return;
    final hadRoute = state.route != null || state.error != null;
    _generation++;
    state = state.copyWith(
      mode: mode,
      routeStatus: RouteStatus.idle,
      route: () => null,
      error: () => null,
    );
    if (hadRoute) await calculate();
  }

  /// Ends route planning and removes the route from the map.
  void clear() {
    _generation++;
    state = NavigationState(mode: state.mode);
  }

  Future<void> calculate() async {
    final origin = state.origin;
    final destination = state.destination;
    if (origin == null || destination == null) return;

    final generation = ++_generation;
    state = state.copyWith(
      routeStatus: RouteStatus.loading,
      route: () => null,
      error: () => null,
    );

    final originPoint = await _resolve(origin);
    final destinationPoint = await _resolve(destination);
    if (!ref.mounted || generation != _generation) return;
    if (originPoint == null || destinationPoint == null) {
      final failure =
          ref.read(locationControllerProvider).failure ??
          LocationFailure.unavailable;
      _fail(RouteLocationError(failure));
      return;
    }
    if (originPoint == destinationPoint) {
      _fail(const RouteSamePointsError());
      return;
    }

    try {
      final route = await ref
          .read(routingRepositoryProvider)
          .route(
            origin: originPoint,
            destination: destinationPoint,
            mode: state.mode,
          );
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        routeStatus: RouteStatus.ready,
        route: () => route,
      );
    } on ServiceException catch (error) {
      logServiceError('routing', error);
      if (!ref.mounted || generation != _generation) return;
      _fail(RouteServiceError(error.failure));
    }
  }

  Future<GeoPoint?> _resolve(Waypoint waypoint) async => switch (waypoint) {
    PointWaypoint(:final point) => point,
    CurrentLocationWaypoint() =>
      (await ref.read(locationControllerProvider.notifier).locate())?.point,
  };

  void _updateWaypoints({
    required Waypoint? origin,
    required Waypoint? destination,
  }) {
    _generation++;
    state = state.copyWith(
      selection: () => null,
      origin: () => origin,
      destination: () => destination,
      routeStatus: RouteStatus.idle,
      route: () => null,
      error: () => null,
    );
  }

  void _fail(RouteError error) {
    state = state.copyWith(routeStatus: RouteStatus.failed, error: () => error);
  }
}

final navigationControllerProvider =
    NotifierProvider<NavigationController, NavigationState>(
      NavigationController.new,
    );
