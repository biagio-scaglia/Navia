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
    this.steps = const [],
  });

  final TravelMode mode;

  /// The path to draw, from origin to destination.
  final List<GeoPoint> geometry;

  final double distanceMeters;
  final Duration duration;

  /// Maneuvers from departure to arrival; empty if the service sent none.
  final List<RouteStep> steps;
}

/// Kinds of maneuvers, following OSRM's `maneuver.type`.
enum ManeuverKind {
  depart,
  turn,
  continueStraight,
  newName,
  merge,
  ramp,
  fork,
  endOfRoad,
  roundabout,
  arrive,
  other,
}

/// Direction of a maneuver, following OSRM's `maneuver.modifier`.
enum ManeuverDirection {
  uturn,
  sharpRight,
  right,
  slightRight,
  straight,
  slightLeft,
  left,
  sharpLeft,
}

/// One maneuver of a route and the stretch that follows it.
@immutable
class RouteStep {
  const RouteStep({
    required this.kind,
    required this.location,
    required this.distanceMeters,
    this.direction,
    this.streetName,
    this.exit,
  });

  final ManeuverKind kind;

  /// Where the maneuver happens.
  final GeoPoint location;

  /// Length of the stretch after the maneuver, up to the next one.
  final double distanceMeters;

  final ManeuverDirection? direction;

  /// The street taken, when it has a name.
  final String? streetName;

  /// Roundabout exit number.
  final int? exit;

  @override
  bool operator ==(Object other) =>
      other is RouteStep &&
      other.kind == kind &&
      other.location == location &&
      other.distanceMeters == distanceMeters &&
      other.direction == direction &&
      other.streetName == streetName &&
      other.exit == exit;

  @override
  int get hashCode =>
      Object.hash(kind, location, distanceMeters, direction, streetName, exit);
}
