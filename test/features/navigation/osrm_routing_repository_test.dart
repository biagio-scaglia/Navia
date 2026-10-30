import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/navigation/data/osrm_routing_repository.dart';
import 'package:navia/features/navigation/domain/navigation_models.dart';
import 'package:navia/shared/models/geo_point.dart';

const _origin = GeoPoint(latitude: 41.1171, longitude: 16.8719);
const _destination = GeoPoint(latitude: 41.1253, longitude: 16.8667);

Map<String, dynamic> _okBody({Object? coordinates}) => {
  'code': 'Ok',
  'routes': [
    {
      'distance': 1670.8,
      'duration': 181.2,
      'geometry': {
        'type': 'LineString',
        'coordinates':
            coordinates ??
            [
              [16.8719, 41.1171],
              [16.8700, 41.1200],
              [16.8667, 41.1253],
            ],
      },
    },
  ],
};

Matcher _failsWith(ServiceFailure failure) => throwsA(
  isA<ServiceException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  group('OsrmRoutingRepository.parse', () {
    test('reads distance, duration and GeoJSON geometry', () {
      final route = OsrmRoutingRepository.parse(_okBody(), TravelMode.walking);

      expect(route.mode, TravelMode.walking);
      expect(route.distanceMeters, 1670.8);
      expect(route.duration, const Duration(milliseconds: 181200));
      expect(route.geometry.first, _origin);
      expect(route.geometry.last, _destination);
      expect(route.geometry, hasLength(3));
    });

    test('maps OSRM error codes', () {
      expect(
        () => OsrmRoutingRepository.parse({
          'code': 'NoRoute',
        }, TravelMode.driving),
        _failsWith(ServiceFailure.noResult),
      );
      expect(
        () => OsrmRoutingRepository.parse({
          'code': 'InvalidQuery',
        }, TravelMode.driving),
        _failsWith(ServiceFailure.invalidRequest),
      );
      expect(
        () => OsrmRoutingRepository.parse({
          'code': 'Surprise',
        }, TravelMode.driving),
        _failsWith(ServiceFailure.unavailable),
      );
    });

    test('rejects malformed routes', () {
      expect(
        () => OsrmRoutingRepository.parse({
          'code': 'Ok',
          'routes': <Object>[],
        }, TravelMode.driving),
        _failsWith(ServiceFailure.noResult),
      );
      expect(
        () => OsrmRoutingRepository.parse(
          _okBody(
            coordinates: [
              [16.87, 41.11],
              [999, 41.12],
            ],
          ),
          TravelMode.driving,
        ),
        _failsWith(ServiceFailure.malformedResponse),
      );
      expect(
        () => OsrmRoutingRepository.parse(
          _okBody(
            coordinates: [
              [16.87, 41.11],
            ],
          ),
          TravelMode.driving,
        ),
        _failsWith(ServiceFailure.malformedResponse),
      );
      expect(
        () => OsrmRoutingRepository.parse({
          'code': 'Ok',
          'routes': [
            {
              'distance': '1 km',
              'duration': 10,
              'geometry': <String, Object>{},
            },
          ],
        }, TravelMode.driving),
        _failsWith(ServiceFailure.malformedResponse),
      );
    });
  });

  group('OsrmRoutingRepository', () {
    late List<Uri> requests;

    OsrmRoutingRepository repository(Map<TravelMode, String> baseUrls) {
      requests = [];
      return OsrmRoutingRepository(
        JsonHttpClient(
          MockClient((request) async {
            requests.add(request.url);
            return http.Response(jsonEncode(_okBody()), 200);
          }),
          userAgent: 'Navia/test',
        ),
        baseUrls: baseUrls,
      );
    }

    test('offers only configured modes', () {
      final router = repository({
        TravelMode.driving: 'https://osrm.example.org/car',
        TravelMode.cycling: '',
      });
      expect(router.supportedModes, {TravelMode.driving});
    });

    test(
      'requests longitude-first coordinates from the mode endpoint',
      () async {
        final router = repository({
          TravelMode.cycling: 'https://osrm.example.org/bike',
        });

        await router.route(
          origin: _origin,
          destination: _destination,
          mode: TravelMode.cycling,
        );

        final uri = requests.single;
        expect(uri.path, '/bike/route/v1/bike/16.8719,41.1171;16.8667,41.1253');
        expect(uri.queryParameters['geometries'], 'geojson');
        expect(uri.queryParameters['overview'], 'full');
      },
    );

    test('rejects unconfigured modes without a request', () {
      final router = repository({
        TravelMode.driving: 'https://osrm.example.org/car',
      });
      expect(
        router.route(
          origin: _origin,
          destination: _destination,
          mode: TravelMode.walking,
        ),
        _failsWith(ServiceFailure.notConfigured),
      );
      expect(requests, isEmpty);
    });
  });
}
