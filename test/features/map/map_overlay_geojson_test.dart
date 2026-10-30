import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/map/data/map_overlay_geojson.dart';
import 'package:navia/features/map/domain/map_overlays.dart';
import 'package:navia/shared/models/geo_point.dart';

const _a = GeoPoint(latitude: 41.1171, longitude: 16.8719);
const _b = GeoPoint(latitude: 41.1253, longitude: 16.8667);

void main() {
  test('encodes a route as a longitude-first LineString', () {
    final json = MapOverlayGeoJson.route([_a, _b]);
    final features = json['features'] as List<Map<String, dynamic>>;
    final geometry = features.single['geometry'] as Map<String, dynamic>;

    expect(json['type'], 'FeatureCollection');
    expect(geometry['type'], 'LineString');
    expect(geometry['coordinates'], [
      [16.8719, 41.1171],
      [16.8667, 41.1253],
    ]);
  });

  test('an empty route clears the line', () {
    expect(MapOverlayGeoJson.route(const [])['features'], isEmpty);
  });

  test('encodes markers with their kind', () {
    final json = MapOverlayGeoJson.markers(const [
      MapMarker(_a, MapMarkerKind.origin),
      MapMarker(_b, MapMarkerKind.destination),
    ]);
    final features = json['features'] as List<Map<String, dynamic>>;

    expect(features.map((f) => (f['properties'] as Map)['kind']), [
      'origin',
      'destination',
    ]);
    expect((features.first['geometry'] as Map)['coordinates'], [
      16.8719,
      41.1171,
    ]);
  });
}
