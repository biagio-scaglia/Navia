import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_point.dart';
import '../domain/navigation_models.dart';
import '../domain/routing_repository.dart';

/// [RoutingRepository] for OSRM servers, one base URL per travel mode.
///
/// See http://project-osrm.org/docs/v5.24.0/api/#route-service.
class OsrmRoutingRepository implements RoutingRepository {
  OsrmRoutingRepository(
    this._client, {
    required Map<TravelMode, String> baseUrls,
    this.minInterval = Duration.zero,
  }) : _baseUrls = {
         for (final entry in baseUrls.entries)
           if (entry.value.isNotEmpty) entry.key: entry.value,
       };

  final JsonHttpClient _client;
  final Map<TravelMode, String> _baseUrls;

  /// Minimum spacing between requests required by the server policy.
  final Duration minInterval;

  final Stopwatch _sinceLastRequest = Stopwatch();

  @override
  Set<TravelMode> get supportedModes => _baseUrls.keys.toSet();

  @override
  Future<NavRoute> route({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) async {
    final baseUrl = _baseUrls[mode];
    if (baseUrl == null) {
      throw const ServiceException(ServiceFailure.notConfigured);
    }
    await _respectRateLimit();

    // OSRM expects longitude,latitude pairs separated by semicolons.
    final coordinates = [
      origin,
      destination,
    ].map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse('$baseUrl/route/v1/${_profile(mode)}/$coordinates')
        .replace(
          queryParameters: const {
            'overview': 'full',
            'geometries': 'geojson',
            'alternatives': 'false',
            'steps': 'false',
          },
        );
    final response = await _client.getJson(uri);
    return parse(response.body, mode);
  }

  /// Parses an OSRM route response.
  static NavRoute parse(Map<String, dynamic> body, TravelMode mode) {
    final code = body['code'];
    if (code != 'Ok') {
      throw ServiceException(switch (code) {
        'NoRoute' || 'NoSegment' => ServiceFailure.noResult,
        'InvalidQuery' ||
        'InvalidValue' ||
        'InvalidInput' ||
        'InvalidOptions' ||
        'TooBig' => ServiceFailure.invalidRequest,
        _ => ServiceFailure.unavailable,
      }, code);
    }

    final routes = body['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const ServiceException(ServiceFailure.noResult);
    }
    final route = routes.first;
    if (route is! Map<String, dynamic>) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
    final distance = route['distance'];
    final duration = route['duration'];
    final geometry = route['geometry'];
    if (distance is! num ||
        duration is! num ||
        distance < 0 ||
        duration < 0 ||
        geometry is! Map<String, dynamic> ||
        geometry['coordinates'] is! List) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }

    final points = <GeoPoint>[];
    for (final position in geometry['coordinates'] as List) {
      final point = GeoPoint.tryParseLngLat(position);
      if (point == null) {
        throw const ServiceException(ServiceFailure.malformedResponse);
      }
      points.add(point);
    }
    if (points.length < 2) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }

    return NavRoute(
      mode: mode,
      geometry: List.unmodifiable(points),
      distanceMeters: distance.toDouble(),
      duration: Duration(milliseconds: (duration * 1000).round()),
    );
  }

  /// OSRM servers serve one profile each and ignore this path segment, but
  /// it is set to the documented profile names for clarity.
  static String _profile(TravelMode mode) => switch (mode) {
    TravelMode.driving => 'car',
    TravelMode.cycling => 'bike',
    TravelMode.walking => 'foot',
  };

  Future<void> _respectRateLimit() async {
    if (_sinceLastRequest.isRunning) {
      final remaining = minInterval - _sinceLastRequest.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
    _sinceLastRequest
      ..reset()
      ..start();
  }
}

/// The configured router. Modes without an endpoint are not offered.
final routingRepositoryProvider = Provider<RoutingRepository>(
  (ref) => OsrmRoutingRepository(
    ref.watch(jsonHttpClientProvider),
    baseUrls: const {
      TravelMode.driving: AppConfig.routingCarUrl,
      TravelMode.cycling: AppConfig.routingBikeUrl,
      TravelMode.walking: AppConfig.routingFootUrl,
    },
    minInterval: AppConfig.routingMinInterval,
  ),
);
