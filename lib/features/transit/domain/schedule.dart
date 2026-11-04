import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';
import 'transit.dart';

/// A line of the timetables.
@immutable
class TransitRoute {
  const TransitRoute({
    required this.index,
    required this.name,
    required this.longName,
    this.color,
  });

  final int index;

  /// Line number, e.g. "02/".
  final String name;
  final String longName;

  /// RGB, when the timetables give one.
  final int? color;
}

/// One stored departure: seconds after the service day's midnight (past
/// 86400 after midnight), route, headsign and service.
typedef RawDeparture = (int seconds, int route, String headsign, int service);

/// One stored trip of a route.
@immutable
class RouteTrip {
  const RouteTrip({
    required this.service,
    required this.shape,
    required this.headsign,
    required this.times,
    required this.distances,
  });

  final int service;
  final int shape;
  final String headsign;

  /// Seconds after the service day's midnight at each stop.
  final List<int> times;

  /// Meters along the shape at each stop.
  final List<int> distances;
}

/// The shapes and trips of one route.
@immutable
class RouteSchedule {
  const RouteSchedule({required this.shapes, required this.trips});

  final List<List<GeoPoint>> shapes;
  final List<RouteTrip> trips;
}

/// A bus where the timetable says it is now.
@immutable
class TransitVehicle {
  const TransitVehicle({
    required this.point,
    required this.bearing,
    required this.headsign,
  });

  final GeoPoint point;

  /// Degrees clockwise from north.
  final double bearing;
  final String headsign;
}

/// Scheduled departures and vehicle positions, computed on the device.
abstract final class TransitSchedule {
  /// Departures from a stop between [now] and [now] + [window], at most
  /// [limit]. Trips of yesterday's service day that run past midnight are
  /// included.
  static List<Departure> departures(
    List<RawDeparture> raw, {
    required List<ServiceDays> services,
    required List<TransitRoute> routes,
    required DateTime now,
    Duration window = const Duration(minutes: 30),
    int limit = 8,
  }) {
    final result = <Departure>[];
    final end = now.add(window);
    for (final dayOffset in const [-1, 0]) {
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      for (final (seconds, route, headsign, service) in raw) {
        // DateTime arithmetic on the calendar day keeps daylight saving
        // changes right.
        final time = DateTime(day.year, day.month, day.day, 0, 0, seconds);
        if (time.isBefore(now) || time.isAfter(end)) continue;
        if (service >= services.length || !services[service].runsOn(day)) {
          continue;
        }
        final line = route < routes.length ? routes[route] : null;
        result.add(
          Departure(
            time: time,
            route: line?.name ?? '?',
            headsign: headsign,
            color: line?.color,
          ),
        );
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result.take(limit).toList();
  }

  /// The next departure after [now], within two days, for a stop with
  /// nothing in the window.
  static Departure? next(
    List<RawDeparture> raw, {
    required List<ServiceDays> services,
    required List<TransitRoute> routes,
    required DateTime now,
  }) {
    final found = departures(
      raw,
      services: services,
      routes: routes,
      now: now,
      window: const Duration(hours: 36),
      limit: 1,
    );
    return found.firstOrNull;
  }

  /// Where the trips of [route] running at [now] are, interpolated between
  /// their stop times along the shape.
  static List<TransitVehicle> vehicles(
    RouteSchedule route, {
    required List<ServiceDays> services,
    required DateTime now,
  }) {
    final result = <TransitVehicle>[];
    for (final dayOffset in const [-1, 0]) {
      final day = DateTime(now.year, now.month, now.day + dayOffset);
      final seconds = now.difference(day).inSeconds;
      for (final trip in route.trips) {
        final times = trip.times;
        if (seconds < times.first || seconds > times.last) continue;
        if (trip.service >= services.length ||
            !services[trip.service].runsOn(day)) {
          continue;
        }
        var i = 0;
        while (i < times.length - 2 && times[i + 1] <= seconds) {
          i++;
        }
        final span = times[i + 1] - times[i];
        final t = span <= 0 ? 0.0 : (seconds - times[i]) / span;
        final along =
            trip.distances[i] +
            (trip.distances[i + 1] - trip.distances[i]) * t.clamp(0.0, 1.0);
        if (trip.shape >= route.shapes.length) continue;
        final position = pointAlong(route.shapes[trip.shape], along);
        if (position == null) continue;
        result.add(
          TransitVehicle(
            point: position.$1,
            bearing: position.$2,
            headsign: trip.headsign,
          ),
        );
      }
    }
    return result;
  }

  /// The point [meters] along [line] and the direction there, in degrees
  /// clockwise from north.
  static (GeoPoint, double)? pointAlong(List<GeoPoint> line, double meters) {
    if (line.length < 2) return null;
    var walked = 0.0;
    for (var i = 0; i < line.length - 1; i++) {
      final a = line[i], b = line[i + 1];
      final length = a.distanceTo(b);
      if (walked + length >= meters || i == line.length - 2) {
        final t = length == 0
            ? 0.0
            : ((meters - walked) / length).clamp(0.0, 1.0);
        return (
          GeoPoint(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t,
          ),
          bearingBetween(a, b),
        );
      }
      walked += length;
    }
    return null;
  }

  static double bearingBetween(GeoPoint a, GeoPoint b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
