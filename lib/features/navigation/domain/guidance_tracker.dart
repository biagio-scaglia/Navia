import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';
import 'navigation_models.dart';

/// What the guidance should do after a position update.
@immutable
class GuidanceUpdate {
  const GuidanceUpdate({
    required this.nextStepIndex,
    required this.distanceToManeuver,
    required this.remainingMeters,
    this.announcement,
    this.arrived = false,
    this.offRoute = false,
  });

  /// Index in [NavRoute.steps] of the next maneuver.
  final int nextStepIndex;

  /// Straight-line distance to the next maneuver.
  final double distanceToManeuver;

  /// Approximate distance left to the destination.
  final double remainingMeters;

  /// Text to speak now, if any.
  final String? announcement;

  final bool arrived;

  /// The position has been away from the route for consecutive updates.
  final bool offRoute;
}

/// Follows the user along a route, one position at a time.
///
/// It is pure Dart: the controller feeds it positions and acts on the
/// returned [GuidanceUpdate]s, which makes the logic testable without GPS.
class GuidanceTracker {
  GuidanceTracker(
    this.route, {
    required this.describe,
    required this.describeAhead,
  }) : _thresholds = _Thresholds.forMode(route.mode);

  final NavRoute route;

  /// Instruction for a maneuver, e.g. "Svolta a destra in Via Sparano".
  final String Function(RouteStep step) describe;

  /// Advance notice, e.g. "Tra 300 metri, svolta a destra".
  final String Function(RouteStep step, double meters) describeAhead;

  final _Thresholds _thresholds;
  int _next = 1;
  bool _announcedAhead = false;
  bool _announcedNear = false;
  int _offRouteCount = 0;

  /// What to say when guidance starts.
  String? get departure {
    final steps = route.steps;
    if (steps.isEmpty) return null;
    return describe(steps.first);
  }

  GuidanceUpdate update(GeoPoint position) {
    final steps = route.steps;
    if (steps.length < 2) {
      return const GuidanceUpdate(
        nextStepIndex: 0,
        distanceToManeuver: 0,
        remainingMeters: 0,
        arrived: true,
      );
    }

    final offRoute =
        distanceToPath(position, route.geometry) > _thresholds.offRoute;
    _offRouteCount = offRoute ? _offRouteCount + 1 : 0;

    String? announcement;
    var distance = position.distanceTo(steps[_next].location);
    // Passed the maneuver: move on to the following one.
    while (distance <= _thresholds.reached && _next < steps.length - 1) {
      _next++;
      _announcedAhead = false;
      _announcedNear = false;
      distance = position.distanceTo(steps[_next].location);
    }

    final step = steps[_next];
    final arrived =
        step.kind == ManeuverKind.arrive && distance <= _thresholds.reached;
    if (arrived) {
      announcement = describe(step);
    } else if (!_announcedNear && distance <= _thresholds.near) {
      _announcedNear = true;
      _announcedAhead = true;
      announcement = describe(step);
    } else if (!_announcedAhead && distance <= _thresholds.ahead) {
      _announcedAhead = true;
      announcement = describeAhead(step, distance);
    }

    var remaining = distance;
    for (var i = _next; i < steps.length; i++) {
      remaining += steps[i].distanceMeters;
    }

    return GuidanceUpdate(
      nextStepIndex: _next,
      distanceToManeuver: distance,
      remainingMeters: remaining,
      announcement: announcement,
      arrived: arrived,
      offRoute: _offRouteCount >= 2,
    );
  }

  /// Shortest distance from [point] to the polyline [path], in meters, on
  /// a local flat projection (accurate at city scale).
  static double distanceToPath(GeoPoint point, List<GeoPoint> path) {
    if (path.isEmpty) return double.infinity;
    final cosLat = math.cos(point.latitude * math.pi / 180);
    (double, double) project(GeoPoint p) => (
      (p.longitude - point.longitude) * 111320 * cosLat,
      (p.latitude - point.latitude) * 110540,
    );
    var best = double.infinity;
    var previous = project(path.first);
    if (path.length == 1) {
      return math.sqrt(previous.$1 * previous.$1 + previous.$2 * previous.$2);
    }
    for (final next in path.skip(1)) {
      final current = project(next);
      final dx = current.$1 - previous.$1;
      final dy = current.$2 - previous.$2;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : ((-previous.$1 * dx - previous.$2 * dy) / lengthSquared).clamp(
              0.0,
              1.0,
            );
      final x = previous.$1 + t * dx;
      final y = previous.$2 + t * dy;
      best = math.min(best, math.sqrt(x * x + y * y));
      previous = current;
    }
    return best;
  }
}

class _Thresholds {
  const _Thresholds({
    required this.ahead,
    required this.near,
    required this.reached,
    required this.offRoute,
  });

  factory _Thresholds.forMode(TravelMode mode) => switch (mode) {
    TravelMode.driving => const _Thresholds(
      ahead: 400,
      near: 60,
      reached: 25,
      offRoute: 60,
    ),
    TravelMode.cycling => const _Thresholds(
      ahead: 200,
      near: 35,
      reached: 20,
      offRoute: 45,
    ),
    TravelMode.walking => const _Thresholds(
      ahead: 100,
      near: 20,
      reached: 15,
      offRoute: 35,
    ),
  };

  /// Distance of the advance notice.
  final double ahead;

  /// Distance of the "now" instruction.
  final double near;

  /// Distance at which a maneuver counts as done.
  final double reached;

  /// Distance from the route that counts as off route.
  final double offRoute;
}
