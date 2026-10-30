import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

enum TravelMode { driving, cycling, walking }

/// An origin or destination of a route.
sealed class Waypoint {
  const Waypoint();
}

/// The device location, resolved only when a route is calculated.
final class CurrentLocationWaypoint extends Waypoint {
  const CurrentLocationWaypoint();

  @override
  bool operator ==(Object other) => other is CurrentLocationWaypoint;

  @override
  int get hashCode => (CurrentLocationWaypoint).hashCode;
}

/// A fixed point, picked on the map or from search results.
final class PointWaypoint extends Waypoint {
  const PointWaypoint(
    this.point, {
    this.label,
    this.description,
    this.category,
  });

  final GeoPoint point;

  /// Name of the place; null for points picked on the map.
  final String? label;

  final String? description;

  /// Italian category label, when known from the data source.
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is PointWaypoint &&
      other.point == point &&
      other.label == label &&
      other.description == description &&
      other.category == category;

  @override
  int get hashCode => Object.hash(point, label, description, category);
}

/// A route returned by a routing service.
@immutable
class NavRoute {
  const NavRoute({
    required this.mode,
    required this.geometry,
    required this.distanceMeters,
    required this.duration,
  });

  final TravelMode mode;

  /// The path to draw, from origin to destination.
  final List<GeoPoint> geometry;

  final double distanceMeters;
  final Duration duration;
}
