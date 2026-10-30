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
          'selected': place.selected,
        },
        'geometry': {'type': 'Point', 'coordinates': place.point.toLngLat()},
      },
  ]);

  static Map<String, dynamic> _collection(
    List<Map<String, dynamic>> features,
  ) => {'type': 'FeatureCollection', 'features': features};
}
