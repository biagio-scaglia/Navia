import '../../../shared/models/geo_point.dart';
import '../../../shared/models/place_category.dart';
import '../domain/map_overlays.dart';

/// Reads OpenMapTiles POI features returned by MapLibre feature queries.
abstract final class MapFeatureParser {
  /// The first feature with a name and point geometry, or null.
  static MapPoi? firstPoi(List<Object?> features) {
    for (final feature in features) {
      final parsed = poi(feature);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static MapPoi? poi(Object? feature) {
    if (feature is! Map) return null;
    final properties = feature['properties'];
    final geometry = feature['geometry'];
    if (properties is! Map || geometry is! Map) return null;
    if (geometry['type'] != 'Point') return null;

    final point = GeoPoint.tryParseLngLat(geometry['coordinates']);
    final name = _text(properties['name:it']) ?? _text(properties['name']);
    if (point == null || name == null) return null;

    return MapPoi(
      name: name,
      point: point,
      category: PlaceCategory.firstLabel([
        _text(properties['subclass']),
        _text(properties['class']),
      ]),
    );
  }

  /// The `key` property of the first feature drawn by Navia's place layers.
  static String? firstPlaceKey(List<Object?> features) {
    for (final feature in features) {
      if (feature is! Map) continue;
      final properties = feature['properties'];
      if (properties is! Map) continue;
      final key = _text(properties['key']);
      if (key != null) return key;
    }
    return null;
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
