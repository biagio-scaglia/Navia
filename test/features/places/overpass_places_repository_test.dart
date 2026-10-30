import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/places/data/overpass_places_repository.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/features/places/domain/poi_category.dart';
import 'package:navia/shared/models/geo_bounds.dart';
import 'package:navia/shared/models/geo_point.dart';

final _bounds = GeoBounds.tryCreate(
  south: 41.11,
  west: 16.86,
  north: 41.13,
  east: 16.88,
)!;

Matcher _failsWith(ServiceFailure failure) => throwsA(
  isA<ServiceException>().having((e) => e.failure, 'failure', failure),
);

OverpassPlacesRepository _repository(MockClientHandler handler) =>
    OverpassPlacesRepository(
      JsonHttpClient(MockClient(handler), userAgent: 'Navia/test'),
      endpoint: 'https://overpass.example/api/interpreter',
    );

void main() {
  test('builds a bounded, limited query for the category tags', () {
    final query = OverpassPlacesRepository.query(
      PoiCategory.transport,
      _bounds,
    );
    expect(
      query,
      '[out:json][timeout:15][bbox:41.11000,16.86000,41.13000,16.88000];'
      '(nwr["highway"~"^(bus_stop)\$"];'
      'nwr["railway"~"^(station|halt|tram_stop)\$"];'
      'nwr["amenity"~"^(bus_station)\$"];);'
      'out tags center 150;',
    );
  });

  group('parse', () {
    test('reads nodes, way centers and every supported tag', () {
      final places = OverpassPlacesRepository.parse({
        'elements': [
          {
            'type': 'node',
            'id': 101,
            'lat': 41.1201,
            'lon': 16.8702,
            'tags': {
              'amenity': 'pharmacy',
              'name': 'Farmacia Centrale',
              'addr:street': 'Via Sparano da Bari',
              'addr:housenumber': '5',
              'addr:city': 'Bari',
              'opening_hours': 'Mo-Sa 08:30-20:00',
              'contact:website': 'farmaciacentrale.example.it',
              'phone': '+39 080 5211111',
              'wheelchair': 'limited',
            },
          },
          {
            'type': 'way',
            'id': 202,
            'center': {'lat': 41.123, 'lon': 16.871},
            'tags': {
              'amenity': 'restaurant',
              'name': 'Trattoria',
              'name:it': 'Trattoria da Nicola',
              'cuisine': 'italian;sea_food',
            },
          },
        ],
      });

      expect(places, hasLength(2));
      final pharmacy = places.first;
      expect(pharmacy.ref, const OsmRef(OsmElementType.node, 101));
      expect(
        pharmacy.point,
        const GeoPoint(latitude: 41.1201, longitude: 16.8702),
      );
      expect(pharmacy.name, 'Farmacia Centrale');
      expect(pharmacy.category, 'Farmacia');
      expect(pharmacy.address, 'Via Sparano da Bari, 5 · Bari');
      expect(pharmacy.openingHours, 'Mo-Sa 08:30-20:00');
      expect(
        pharmacy.website.toString(),
        'https://farmaciacentrale.example.it',
      );
      expect(pharmacy.phone, '+39 080 5211111');
      expect(pharmacy.wheelchair, WheelchairAccess.limited);

      final restaurant = places.last;
      expect(restaurant.ref.key, 'way/202');
      expect(restaurant.name, 'Trattoria da Nicola');
      expect(restaurant.cuisine, 'italian, sea food');
    });

    test('keeps places with missing optional metadata as missing', () {
      final place = OverpassPlacesRepository.parse({
        'elements': [
          {
            'type': 'node',
            'id': 7,
            'lat': 41.12,
            'lon': 16.87,
            'tags': {
              'amenity': 'parking',
              'phone': 'chiedere al bar',
              'website': 'javascript:void(0)',
              'wheelchair': 'maybe',
              'name': '  ',
            },
          },
        ],
      }).single;

      expect(place.name, isNull);
      expect(place.category, 'Parcheggio');
      expect(place.address, isNull);
      expect(place.openingHours, isNull);
      expect(place.website, isNull);
      expect(place.phone, isNull);
      expect(place.cuisine, isNull);
      expect(place.wheelchair, isNull);
    });

    test('skips elements without a usable id or position', () {
      final places = OverpassPlacesRepository.parse({
        'elements': [
          {'type': 'node', 'id': 1, 'lat': 120, 'lon': 16.8},
          {'type': 'way', 'id': 2},
          {'type': 'area', 'id': 3, 'lat': 41.1, 'lon': 16.8},
          {'type': 'node', 'id': 'x', 'lat': 41.1, 'lon': 16.8},
          'garbage',
        ],
      });
      expect(places, isEmpty);
    });

    test('reports server errors without results as unavailable', () {
      expect(
        () => OverpassPlacesRepository.parse({
          'elements': <Object>[],
          'remark': 'runtime error: Query timed out in "query" at line 1',
        }),
        _failsWith(ServiceFailure.unavailable),
      );
      expect(
        () => OverpassPlacesRepository.parse({'version': 0.6}),
        _failsWith(ServiceFailure.malformedResponse),
      );
    });
  });

  test('sends the query to the configured endpoint', () async {
    late Uri requested;
    final repository = _repository((request) async {
      requested = request.url;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 9,
                'lat': 41.12,
                'lon': 16.87,
                'tags': {'amenity': 'cafe', 'name': 'Caffè'},
              },
            ],
          }),
        ),
        200,
      );
    });

    final places = await repository.fetch(PoiCategory.cafes, _bounds);

    expect(requested.host, 'overpass.example');
    expect(requested.queryParameters['data'], contains('amenity'));
    expect(places.single.name, 'Caffè');
  });

  test('maps rate limiting and server failures', () async {
    final busy = _repository((_) async => http.Response('', 429));
    await expectLater(
      busy.fetch(PoiCategory.cafes, _bounds),
      _failsWith(ServiceFailure.rateLimited),
    );
    final down = _repository((_) async => http.Response('', 504));
    await expectLater(
      down.fetch(PoiCategory.cafes, _bounds),
      _failsWith(ServiceFailure.unavailable),
    );
  });

  group('when the server is busy', () {
    OverpassPlacesRepository retrying(MockClientHandler handler) =>
        OverpassPlacesRepository(
          JsonHttpClient(MockClient(handler), userAgent: 'Navia/test'),
          endpoint: 'https://overpass.example/api/interpreter',
          retryDelays: const [Duration.zero, Duration.zero],
        );

    test('retries with backoff and returns the later answer', () async {
      final statuses = [502, 429];
      var calls = 0;
      final repository = retrying((_) async {
        calls++;
        if (statuses.isNotEmpty) {
          return http.Response('busy', statuses.removeAt(0));
        }
        return http.Response(jsonEncode({'elements': <Object>[]}), 200);
      });

      expect(await repository.fetch(PoiCategory.parks, _bounds), isEmpty);
      expect(calls, 3);
    });

    test('gives up after the configured attempts', () async {
      var calls = 0;
      final repository = retrying((_) async {
        calls++;
        return http.Response('busy', 504);
      });

      await expectLater(
        repository.fetch(PoiCategory.parks, _bounds),
        _failsWith(ServiceFailure.unavailable),
      );
      expect(calls, 3);
    });

    test('does not retry requests the server rejected', () async {
      var calls = 0;
      final repository = retrying((_) async {
        calls++;
        return http.Response(jsonEncode({'remark': 'bad query'}), 400);
      });

      await expectLater(
        repository.fetch(PoiCategory.parks, _bounds),
        _failsWith(ServiceFailure.invalidRequest),
      );
      expect(calls, 1);
    });
  });
}
