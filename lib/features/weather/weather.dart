import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/network/json_http_client.dart';
import '../../shared/models/geo_point.dart';

/// Current weather and today's range at a place.
@immutable
class WeatherReport {
  const WeatherReport({
    required this.temperature,
    required this.code,
    required this.windKmh,
    this.max,
    this.min,
  });

  /// Degrees Celsius.
  final double temperature;

  /// WMO weather interpretation code.
  final int code;
  final double windKmh;
  final double? max;
  final double? min;

  /// Italian description of [code].
  String get description => switch (code) {
    0 => 'Sereno',
    1 => 'Prevalentemente sereno',
    2 => 'Parzialmente nuvoloso',
    3 => 'Nuvoloso',
    45 || 48 => 'Nebbia',
    51 || 53 || 55 || 56 || 57 => 'Pioviggine',
    61 || 63 || 65 || 66 || 67 => 'Pioggia',
    71 || 73 || 75 || 77 => 'Neve',
    80 || 81 || 82 => 'Rovesci',
    85 || 86 => 'Rovesci di neve',
    95 || 96 || 99 => 'Temporale',
    _ => 'Condizioni non disponibili',
  };

  IconData get icon => switch (code) {
    0 || 1 => Icons.wb_sunny_rounded,
    2 => Icons.wb_cloudy_rounded,
    3 => Icons.cloud_rounded,
    45 || 48 => Icons.foggy,
    71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
    95 || 96 || 99 => Icons.thunderstorm_rounded,
    >= 51 && <= 82 => Icons.water_drop_rounded,
    _ => Icons.cloud_queue_rounded,
  };

  static WeatherReport? parse(Map<String, dynamic> body) {
    final current = body['current'];
    if (current is! Map) return null;
    final temperature = current['temperature_2m'];
    final code = current['weather_code'];
    final wind = current['wind_speed_10m'];
    if (temperature is! num || code is! int || wind is! num) return null;
    final daily = body['daily'];
    num? first(String key) {
      final values = daily is Map ? daily[key] : null;
      return values is List && values.isNotEmpty && values.first is num
          ? values.first as num
          : null;
    }

    return WeatherReport(
      temperature: temperature.toDouble(),
      code: code,
      windKmh: wind.toDouble(),
      max: first('temperature_2m_max')?.toDouble(),
      min: first('temperature_2m_min')?.toDouble(),
    );
  }
}

/// Reads the weather from Open-Meteo (free, no key, open data).
///
/// Coordinates are rounded to two decimals (about 1 km): enough for a
/// forecast, and it does not reveal the exact destination.
class WeatherRepository {
  WeatherRepository(this._client, {required this.endpoint});

  final JsonHttpClient _client;
  final String endpoint;

  Future<WeatherReport?> at(GeoPoint point) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'latitude': point.latitude.toStringAsFixed(2),
        'longitude': point.longitude.toStringAsFixed(2),
        'current': 'temperature_2m,weather_code,wind_speed_10m',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'forecast_days': '1',
        'timezone': 'auto',
      },
    );
    final response = await _client.getJson(uri);
    if (response.statusCode >= 400) {
      throw ServiceException(ServiceFailure.unavailable, response.statusCode);
    }
    return WeatherReport.parse(response.body);
  }
}

final weatherRepositoryProvider = Provider<WeatherRepository?>((ref) {
  const endpoint = AppConfig.weatherUrl;
  if (endpoint.isEmpty) return null;
  return WeatherRepository(
    ref.watch(jsonHttpClientProvider),
    endpoint: endpoint,
  );
});

/// Weather near [GeoPoint], rounded so nearby places share one request.
final weatherProvider = FutureProvider.autoDispose
    .family<WeatherReport?, GeoPoint>((ref, point) {
      final repository = ref.watch(weatherRepositoryProvider);
      if (repository == null) return Future.value();
      return repository.at(point);
    });

/// The point used as weather key: two decimals.
GeoPoint weatherKey(GeoPoint point) => GeoPoint(
  latitude: double.parse(point.latitude.toStringAsFixed(2)),
  longitude: double.parse(point.longitude.toStringAsFixed(2)),
);

/// A compact weather line: icon, temperature, conditions and today's
/// range. Shows nothing while loading or on failure.
class WeatherLine extends ConsumerWidget {
  const WeatherLine({super.key, required this.point, this.prefix});

  final GeoPoint point;

  /// E.g. "A destinazione", before the temperature.
  final String? prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(weatherProvider(weatherKey(point))).value;
    if (report == null) return const SizedBox.shrink();
    final range = report.max != null && report.min != null
        ? ' · max ${report.max!.round()}° min ${report.min!.round()}°'
        : '';
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      label:
          '${prefix ?? 'Meteo'}: ${report.temperature.round()} gradi, '
          '${report.description}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(report.icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (prefix != null) TextSpan(text: '$prefix: '),
                    TextSpan(
                      text: '${report.temperature.round()}°',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' · ${report.description}$range'),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text('Open-Meteo', style: muted),
          ],
        ),
      ),
    );
  }
}
