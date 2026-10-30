import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/search/data/photon_geocoding_repository.dart';
import 'package:navia/shared/models/geo_point.dart';

Map<String, dynamic> _feature(
  Map<String, dynamic> properties,
  List<num> lngLat,
) => {
  'type': 'Feature',
  'geometry': {'type': 'Point', 'coordinates': lngLat},
  'properties': properties,
};

void main() {
  group('PhotonGeocodingRepository.parse', () {
    test('builds places with name, description and coordinates', () {
      final places = PhotonGeocodingRepository.parse({
        'features': [
          _feature(
            {
              'name': 'Teatro Petruzzelli',
              'street': 'Corso Cavour',
              'housenumber': '12',
              'city': 'Bari',
              'state': 'Puglia',
              'country': 'Italia',
            },
            [16.8721, 41.1225],
          ),
        ],
      });

      expect(places, hasLength(1));
      expect(places.single.name, 'Teatro Petruzzelli');
      expect(places.single.description, 'Corso Cavour, 12 · Bari · Puglia');
      expect(
        places.single.point,
        const GeoPoint(latitude: 41.1225, longitude: 16.8721),
      );
    });

    test('labels known categories and omits unknown ones', () {
      final places = PhotonGeocodingRepository.parse({
        'features': [
          _feature(
            {
              'name': 'Farmacia Centrale',
              'osm_key': 'amenity',
              'osm_value': 'pharmacy',
              'type': 'house',
            },
            [16.87, 41.12],
          ),
          _feature(
            {
              'name': 'Via Sparano da Bari',
              'osm_key': 'highway',
              'osm_value': 'pedestrian',
              'type': 'street',
            },
            [16.87, 41.12],
          ),
          _feature(
            {'name': 'Something', 'osm_value': 'unknown_value'},
            [16.87, 41.12],
          ),
        ],
      });

      expect(places.map((p) => p.category), ['Farmacia', 'Strada', null]);
    });

    test('falls back to the street when there is no name', () {
      final places = PhotonGeocodingRepository.parse({
        'features': [
          _feature(
            {
              'street': 'Via Sparano da Bari',
              'housenumber': '5',
              'city': 'Bari',
              'country': 'Italia',
            },
            [16.8698, 41.1202],
          ),
        ],
      });

      expect(places.single.name, 'Via Sparano da Bari, 5');
      expect(places.single.description, 'Bari · Italia');
    });

    test('skips features with invalid coordinates or no name', () {
      final places = PhotonGeocodingRepository.parse({
        'features': [
          _feature({'name': 'Out of range'}, [200, 41]),
          _feature({'country': 'Italia'}, [16.87, 41.12]),
          'not a feature',
          {'type': 'Feature'},
          _feature({'name': 'Bari'}, [16.87, 41.12]),
        ],
      });

      expect(places.map((p) => p.name), ['Bari']);
    });

    test('rejects responses without a feature list', () {
      expect(
        () => PhotonGeocodingRepository.parse({'message': 'error'}),
        throwsA(
          isA<ServiceException>().having(
            (e) => e.failure,
            'failure',
            ServiceFailure.malformedResponse,
          ),
        ),
      );
    });
  });

  test('queries Photon with location bias and local language', () async {
    late Uri requested;
    final repository = PhotonGeocodingRepository(
      JsonHttpClient(
        MockClient((request) async {
          requested = request.url;
          return http.Response('{"features":[]}', 200);
        }),
        userAgent: 'Navia/test',
      ),
      baseUrl: 'https://photon.example.org',
    );

    final places = await repository.search(
      'via sparano',
      near: const GeoPoint(latitude: 41.1171, longitude: 16.8719),
    );

    expect(places, isEmpty);
    expect(requested.host, 'photon.example.org');
    expect(requested.path, '/api/');
    expect(requested.queryParameters, {
      'q': 'via sparano',
      'limit': '8',
      'lang': 'default',
      'lat': '41.12',
      'lon': '16.87',
    });
  });

  test('reverse geocodes the nearest place with full precision', () async {
    late Uri requested;
    final repository = PhotonGeocodingRepository(
      JsonHttpClient(
        MockClient((request) async {
          requested = request.url;
          return http.Response(
            '{"features":[{"type":"Feature","geometry":{"type":"Point",'
            '"coordinates":[16.8698,41.1202]},"properties":{"street":'
            '"Via Sparano da Bari","housenumber":"5","city":"Bari",'
            '"type":"house"}}]}',
            200,
          );
        }),
        userAgent: 'Navia/test',
      ),
      baseUrl: 'https://photon.example.org',
    );

    final place = await repository.reverse(
      const GeoPoint(latitude: 41.12021, longitude: 16.86985),
    );

    expect(requested.path, '/reverse');
    expect(requested.queryParameters['lat'], '41.120210');
    expect(requested.queryParameters['lon'], '16.869850');
    expect(place?.name, 'Via Sparano da Bari, 5');
    expect(place?.category, 'Indirizzo');
  });

  test('reverse geocoding returns null when nothing is found', () async {
    final repository = PhotonGeocodingRepository(
      JsonHttpClient(
        MockClient((_) async => http.Response('{"features":[]}', 200)),
        userAgent: 'Navia/test',
      ),
      baseUrl: 'https://photon.example.org',
    );

    expect(
      await repository.reverse(const GeoPoint(latitude: 0.5, longitude: 0.5)),
      isNull,
    );
  });
}
