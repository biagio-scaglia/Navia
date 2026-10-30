import 'package:flutter/foundation.dart';

/// A WGS84 geographic coordinate, independent of any map renderer.
///
/// Fields are named explicitly to avoid latitude/longitude ordering mistakes.
/// Note that GeoJSON and most routing APIs (OSRM, Valhalla, GraphHopper) use
/// `[longitude, latitude]` order: use [toLngLat] when serializing for them.
@immutable
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude})
    : assert(latitude >= -90 && latitude <= 90, 'latitude out of range'),
      assert(longitude >= -180 && longitude <= 180, 'longitude out of range');

  /// Degrees north of the equator, in the range [-90, 90].
  final double latitude;

  /// Degrees east of the prime meridian, in the range [-180, 180].
  final double longitude;

  /// Coordinates in GeoJSON order: `[longitude, latitude]`.
  List<double> toLngLat() => [longitude, latitude];

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint(lat: $latitude, lng: $longitude)';
}
