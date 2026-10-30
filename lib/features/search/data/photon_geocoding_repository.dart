import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_point.dart';
import '../domain/geocoding_repository.dart';
import '../domain/place.dart';

/// [GeocodingRepository] for the Photon geocoder (https://photon.komoot.io),
/// which is built on OpenStreetMap data and supports search-as-you-type.
class PhotonGeocodingRepository implements GeocodingRepository {
  PhotonGeocodingRepository(this._client, {required this.baseUrl});

  static const _limit = 8;

  final JsonHttpClient _client;
  final String baseUrl;

  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) async {
    final uri = Uri.parse('$baseUrl/api/').replace(
      queryParameters: {
        'q': query,
        'limit': '$_limit',
        // "default" returns local names, i.e. Italian names in Italy.
        'lang': 'default',
        // Bias only: rounded to ~1 km so a precise position is never sent.
        if (near != null) ...{
          'lat': near.latitude.toStringAsFixed(2),
          'lon': near.longitude.toStringAsFixed(2),
        },
      },
    );
    final response = await _client.getJson(uri);
    if (response.statusCode != 200) {
      throw ServiceException(
        ServiceFailure.invalidRequest,
        'HTTP ${response.statusCode}',
      );
    }
    return parse(response.body);
  }

  /// Parses a Photon GeoJSON response. Features without a usable name or
  /// valid coordinates are skipped.
  static List<Place> parse(Map<String, dynamic> body) {
    final features = body['features'];
    if (features is! List) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
    final places = <Place>[];
    for (final feature in features) {
      if (feature is! Map<String, dynamic>) continue;
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry is! Map<String, dynamic> ||
          properties is! Map<String, dynamic>) {
        continue;
      }
      final point = GeoPoint.tryParseLngLat(geometry['coordinates']);
      final name = _name(properties);
      if (point == null || name == null) continue;
      places.add(
        Place(
          name: name,
          description: _description(properties, name),
          point: point,
        ),
      );
    }
    return places;
  }

  static String? _string(Map<String, dynamic> properties, String key) {
    final value = properties[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static String? _streetLine(Map<String, dynamic> properties) {
    final street = _string(properties, 'street');
    if (street == null) return null;
    final number = _string(properties, 'housenumber');
    return number == null ? street : '$street, $number';
  }

  static String? _name(Map<String, dynamic> properties) =>
      _string(properties, 'name') ??
      _streetLine(properties) ??
      _string(properties, 'city');

  static String? _description(Map<String, dynamic> properties, String name) {
    final parts = <String>[];
    for (final part in [
      _streetLine(properties),
      _string(properties, 'city') ?? _string(properties, 'county'),
      _string(properties, 'state'),
      _string(properties, 'country'),
    ]) {
      if (part != null && part != name && !parts.contains(part)) {
        parts.add(part);
      }
    }
    return parts.isEmpty ? null : parts.take(3).join(' · ');
  }
}

/// The configured geocoder, or null when search is disabled in this build.
final geocodingRepositoryProvider = Provider<GeocodingRepository?>((ref) {
  if (AppConfig.geocodingUrl.isEmpty) return null;
  return PhotonGeocodingRepository(
    ref.watch(jsonHttpClientProvider),
    baseUrl: AppConfig.geocodingUrl,
  );
});
