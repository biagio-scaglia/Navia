import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/discover/discover.dart';
import 'package:navia/features/reach/reach.dart';
import 'package:navia/shared/models/geo_point.dart';

const _center = GeoPoint(latitude: 41.1253, longitude: 16.8667);

Map<String, dynamic> _page(String title, double lat, double lon) => {
  'title': title,
  'fullurl': 'https://it.wikipedia.org/wiki/${title.replaceAll(' ', '_')}',
  'description': 'luogo di Bari',
  'coordinates': [
    {'lat': lat, 'lon': lon},
  ],
  'thumbnail': {'source': 'https://upload.wikimedia.org/x.jpg'},
};

void main() {
  group('NearbyArticlesRepository.parse', () {
    test('sorts by distance and skips administrative areas', () {
      final articles = NearbyArticlesRepository.parse({
        'query': {
          'pages': [
            _page('Castello Svevo', 41.1288, 16.8662),
            _page('Provincia di Bari', 41.1253, 16.8667),
            _page('Teatro Petruzzelli', 41.1236, 16.8732),
            {
              'title': 'Senza coordinate',
              'fullurl': 'https://it.wikipedia.org',
            },
          ],
        },
      }, _center);

      // The castle is about 390 m away, the theater about 575 m.
      expect(articles.map((a) => a.title), [
        'Castello Svevo',
        'Teatro Petruzzelli',
      ]);
      expect(articles.first.thumbnail?.host, 'upload.wikimedia.org');
      expect(articles.last.distanceMeters, greaterThan(500));
    });

    test('returns nothing for unexpected answers', () {
      expect(NearbyArticlesRepository.parse({'error': 'x'}, _center), isEmpty);
    });
  });

  group('ReachRepository.parse', () {
    List<List<double>> square(double size) => [
      [16.86, 41.12],
      [16.86 + size, 41.12],
      [16.86 + size, 41.12 + size],
      [16.86, 41.12 + size],
      [16.86, 41.12],
    ];

    test('reads polygons and multipolygons, largest first', () {
      final contours = ReachRepository.parse({
        'type': 'FeatureCollection',
        'features': [
          {
            'properties': {'contour': 5.0},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [square(0.01)],
            },
          },
          {
            'properties': {'contour': 15.0},
            'geometry': {
              'type': 'MultiPolygon',
              'coordinates': [
                [square(0.03)],
                [square(0.002)],
              ],
            },
          },
          {
            'properties': {'contour': 10.0},
            'geometry': {
              'type': 'Point',
              'coordinates': [16.8, 41.1],
            },
          },
        ],
      });

      expect(contours.map((c) => c.minutes), [15, 5]);
      expect(contours.first.rings, hasLength(2));
      expect(contours.last.rings.single, hasLength(5));
    });
  });
}
