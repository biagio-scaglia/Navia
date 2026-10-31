import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/weather/weather.dart';
import 'package:navia/shared/models/geo_point.dart';

void main() {
  test('parses current weather and today range', () {
    final report = WeatherReport.parse({
      'current': {
        'temperature_2m': 16.3,
        'weather_code': 80,
        'wind_speed_10m': 11.6,
      },
      'daily': {
        'temperature_2m_max': [16.5],
        'temperature_2m_min': [13.7],
      },
    })!;
    expect(report.temperature, 16.3);
    expect(report.description, 'Rovesci');
    expect(report.max, 16.5);
    expect(report.min, 13.7);
    expect(WeatherReport.parse({'current': 'x'}), isNull);
  });

  test('describes WMO codes in Italian', () {
    String text(int code) =>
        WeatherReport(temperature: 20, code: code, windKmh: 0).description;
    expect(text(0), 'Sereno');
    expect(text(3), 'Nuvoloso');
    expect(text(63), 'Pioggia');
    expect(text(95), 'Temporale');
    expect(text(42), 'Condizioni non disponibili');
  });

  test('sends coordinates rounded to about 1 km', () async {
    late Uri requested;
    final repository = WeatherRepository(
      JsonHttpClient(
        MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'current': {
                'temperature_2m': 20.0,
                'weather_code': 0,
                'wind_speed_10m': 5.0,
              },
            }),
            200,
          );
        }),
        userAgent: 'Navia/test',
      ),
      endpoint: 'https://weather.example/v1/forecast',
    );

    final report = await repository.at(
      const GeoPoint(latitude: 41.123456, longitude: 16.876543),
    );
    expect(requested.queryParameters['latitude'], '41.12');
    expect(requested.queryParameters['longitude'], '16.88');
    expect(report?.description, 'Sereno');
    expect(
      weatherKey(const GeoPoint(latitude: 41.123456, longitude: 16.876543)),
      const GeoPoint(latitude: 41.12, longitude: 16.88),
    );
  });
}
