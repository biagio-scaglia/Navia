import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../../shared/models/geo_point.dart';
import '../domain/map_overlays.dart';

/// GeoJSON encoding of Navia's overlays. Positions are `[longitude, latitude]`.
abstract final class MapOverlayGeoJson {
  static Map<String, dynamic> route(List<GeoPoint> geometry) => _collection([
    if (geometry.length >= 2)
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'LineString',
          'coordinates': [for (final point in geometry) point.toLngLat()],
        },
      },
  ]);

  static Map<String, dynamic> markers(List<MapMarker> markers) => _collection([
    for (final marker in markers)
      {
        'type': 'Feature',
        'properties': {'kind': marker.kind.name},
        'geometry': {'type': 'Point', 'coordinates': marker.point.toLngLat()},
      },
  ]);

  static Map<String, dynamic> places(List<MapPlace> places) => _collection([
    for (final place in places)
      {
        'type': 'Feature',
        'properties': {
          'key': place.key,
          'name': place.name ?? '',
          'image': place.imageId,
          'selected': place.selected,
        },
        'geometry': {'type': 'Point', 'coordinates': place.point.toLngLat()},
      },
  ]);

  static Map<String, dynamic> areas(List<MapArea> areas) => _collection([
    for (final area in areas)
      {
        'type': 'Feature',
        'properties': {'level': area.level},
        'geometry': {
          'type': 'MultiPolygon',
          'coordinates': [
            for (final ring in area.rings) [ring],
          ],
        },
      },
  ]);

  /// Small squares under each place, extruded into colored columns.
  static Map<String, dynamic> placeColumns(List<MapPlace> places) =>
      _collection([
        for (final place in places)
          if (place.column)
            {
              'type': 'Feature',
              'properties': {
                'color': _hex(place.color),
                'selected': place.selected,
              },
              'geometry': {
                'type': 'Polygon',
                'coordinates': [_square(place.point, _columnHalfSide)],
              },
            },
      ]);

  static Map<String, dynamic> lines(List<MapLine> lines) => _collection([
    for (final line in lines)
      if (line.points.length >= 2)
        {
          'type': 'Feature',
          'properties': {'color': _hex(line.color)},
          'geometry': {
            'type': 'LineString',
            'coordinates': [for (final p in line.points) p.toLngLat()],
          },
        },
  ]);

  /// Vehicles as points, for the flat markers seen from afar.
  static Map<String, dynamic> vehiclePoints(List<MapVehicle> vehicles) =>
      _collection([
        for (final vehicle in vehicles)
          {
            'type': 'Feature',
            'properties': {'color': _hex(vehicle.color)},
            'geometry': {
              'type': 'Point',
              'coordinates': vehicle.point.toLngLat(),
            },
          },
      ]);

  /// Vehicles as bus-sized footprints, extruded into small 3D models: a
  /// body with a short nose, so the direction shows.
  static Map<String, dynamic> vehicleBodies(List<MapVehicle> vehicles) =>
      _collection([
        for (final vehicle in vehicles)
          {
            'type': 'Feature',
            'properties': {'color': _hex(vehicle.color)},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [_vehicleOutline(vehicle)],
            },
          },
      ]);

  /// A 12 m by 2.6 m bus, its front slightly tapered.
  static List<List<double>> _vehicleOutline(MapVehicle vehicle) {
    const halfLength = 6.0, halfWidth = 1.3, nose = 0.5;
    final angle = vehicle.bearing * math.pi / 180;
    final (sin, cos) = (math.sin(angle), math.cos(angle));
    final lat = vehicle.point.latitude, lng = vehicle.point.longitude;
    const mLat = 1 / 111320;
    final mLng = 1 / (111320 * math.cos(lat * math.pi / 180));
    // Forward along the bearing, right across it, in meters.
    List<double> at(double forward, double right) => [
      lng + (forward * sin + right * cos) * mLng,
      lat + (forward * cos - right * sin) * mLat,
    ];
    final outline = [
      at(-halfLength, -halfWidth),
      at(halfLength - nose, -halfWidth),
      at(halfLength, -halfWidth + nose),
      at(halfLength, halfWidth - nose),
      at(halfLength - nose, halfWidth),
      at(-halfLength, halfWidth),
    ];
    return [...outline, outline.first];
  }

  /// Half side of a column, in meters.
  static const _columnHalfSide = 4.0;

  static List<List<double>> _square(GeoPoint center, double halfMeters) {
    final dLat = halfMeters / 111320;
    final dLng =
        halfMeters / (111320 * math.cos(center.latitude * math.pi / 180));
    final (lat, lng) = (center.latitude, center.longitude);
    return [
      [lng - dLng, lat - dLat],
      [lng + dLng, lat - dLat],
      [lng + dLng, lat + dLat],
      [lng - dLng, lat + dLat],
      [lng - dLng, lat - dLat],
    ];
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Map<String, dynamic> _collection(
    List<Map<String, dynamic>> features,
  ) => {'type': 'FeatureCollection', 'features': features};
}
