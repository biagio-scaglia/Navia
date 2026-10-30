import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/map/data/map_feature_parser.dart';
import 'package:navia/shared/models/geo_point.dart';
import 'package:navia/shared/models/place_category.dart';

Map<String, Object?> _poi(Map<String, Object?> properties, {Object? coords}) =>
    {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': coords ?? [16.8721, 41.1225],
      },
      'properties': properties,
    };

void main() {
  group('MapFeatureParser', () {
    test('reads name, Italian category and point', () {
      final poi = MapFeatureParser.poi(
        _poi({'name': 'Teatro Petruzzelli', 'class': 'theatre'}),
      );

      expect(poi?.name, 'Teatro Petruzzelli');
      expect(poi?.category, 'Teatro');
      expect(poi?.point, const GeoPoint(latitude: 41.1225, longitude: 16.8721));
    });

    test('prefers the Italian name and the specific subclass', () {
      final poi = MapFeatureParser.poi(
        _poi({
          'name': 'Bari Centrale',
          'name:it': 'Stazione di Bari Centrale',
          'class': 'railway',
          'subclass': 'station',
        }),
      );

      expect(poi?.name, 'Stazione di Bari Centrale');
      expect(poi?.category, 'Stazione');
    });

    test('omits unknown categories instead of inventing one', () {
      final poi = MapFeatureParser.poi(
        _poi({'name': 'Somewhere', 'class': 'unusual_tag'}),
      );
      expect(poi?.category, isNull);
    });

    test('skips unnamed, non-point and invalid features', () {
      expect(MapFeatureParser.poi(_poi({'class': 'cafe'})), isNull);
      expect(
        MapFeatureParser.poi({
          'geometry': {'type': 'Polygon', 'coordinates': <Object>[]},
          'properties': {'name': 'Area'},
        }),
        isNull,
      );
      expect(
        MapFeatureParser.poi(_poi({'name': 'Bad'}, coords: [500, 41])),
        isNull,
      );
      expect(MapFeatureParser.poi('not a feature'), isNull);
    });

    test('returns the first usable feature', () {
      final poi = MapFeatureParser.firstPoi([
        _poi({'class': 'cafe'}),
        _poi({'name': 'Caffè Centrale', 'class': 'cafe'}),
      ]);
      expect(poi?.name, 'Caffè Centrale');
      expect(MapFeatureParser.firstPoi(const []), isNull);
    });
  });

  group('PlaceCategory', () {
    test('translates known OSM values case-insensitively', () {
      expect(PlaceCategory.label('pharmacy'), 'Farmacia');
      expect(PlaceCategory.label('Restaurant'), 'Ristorante');
    });

    test('returns null for unknown or missing values', () {
      expect(PlaceCategory.label('xyz'), isNull);
      expect(PlaceCategory.label(null), isNull);
      expect(PlaceCategory.firstLabel([null, 'xyz', 'park']), 'Parco');
    });
  });
}
