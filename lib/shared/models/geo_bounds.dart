import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'geo_point.dart';

/// A latitude/longitude rectangle, such as the visible map area.
///
/// Bounds crossing the antimeridian are not supported: Navia's areas of use
/// never span it, and [tryCreate] rejects them.
@immutable
class GeoBounds {
  const GeoBounds._(this.south, this.west, this.north, this.east);

  final double south;
  final double west;
  final double north;
  final double east;

  static GeoBounds? tryCreate({
    required double south,
    required double west,
    required double north,
    required double east,
  }) {
    final values = [south, west, north, east];
    if (values.any((v) => !v.isFinite)) return null;
    if (south < -90 || north > 90 || west < -180 || east > 180) return null;
    if (south >= north || west >= east) return null;
    return GeoBounds._(south, west, north, east);
  }

  GeoPoint get center =>
      GeoPoint(latitude: (south + north) / 2, longitude: (west + east) / 2);

  double get latitudeSpan => north - south;
  double get longitudeSpan => east - west;

  bool containsPoint(GeoPoint point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  bool containsBounds(GeoBounds other) =>
      other.south >= south &&
      other.north <= north &&
      other.west >= west &&
      other.east <= east;

  /// Grows each side by [fraction] of the span, clamped to valid values.
  GeoBounds expandedBy(double fraction) {
    final dLat = latitudeSpan * fraction;
    final dLng = longitudeSpan * fraction;
    return GeoBounds._(
      math.max(-90, south - dLat),
      math.max(-180, west - dLng),
      math.min(90, north + dLat),
      math.min(180, east + dLng),
    );
  }

  /// Rounds the sides outwards to a [step]-degree grid.
  ///
  /// Nearby views then produce identical bounds, which makes cached results
  /// reusable and keeps requests from revealing the exact viewport.
  GeoBounds snappedTo(double step) => GeoBounds._(
    math.max(-90, (south / step).floorToDouble() * step),
    math.max(-180, (west / step).floorToDouble() * step),
    math.min(90, (north / step).ceilToDouble() * step),
    math.min(180, (east / step).ceilToDouble() * step),
  );

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);

  @override
  String toString() => 'GeoBounds($south, $west, $north, $east)';
}
