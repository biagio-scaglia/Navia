import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_bounds.dart';
import '../../../shared/models/geo_point.dart';
import '../../../shared/models/place_category.dart';
import '../domain/place_links.dart';
import '../domain/places_repository.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';

/// [PlacesRepository] backed by an Overpass API server.
///
/// One request covers one category in one area, returns at most
/// [PlacesRepository.maxResults] objects with their tags and centers, and is
/// spaced from the previous one by [minInterval]. The public servers are
/// shared community infrastructure: see https://dev.overpass-api.de/overpass-doc/en/preface/commons.html.
class OverpassPlacesRepository implements PlacesRepository {
  OverpassPlacesRepository(
    this._client, {
    required this.endpoint,
    this.minInterval = Duration.zero,
  });

  final JsonHttpClient _client;
  final String endpoint;

  /// Minimum spacing between requests, to stay a light user of the server.
  final Duration minInterval;

  final Stopwatch _sinceLastRequest = Stopwatch();

  /// Server-side time limit, in seconds; small areas answer much faster.
  static const _timeoutSeconds = 15;

  @override
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds) async {
    await _respectRateLimit();
    final uri = Uri.parse(
      endpoint,
    ).replace(queryParameters: {'data': query(category, bounds)});
    final response = await _client.getJson(uri);
    if (response.statusCode >= 400) {
      throw ServiceException(
        ServiceFailure.invalidRequest,
        'HTTP ${response.statusCode}',
      );
    }
    return parse(response.body);
  }

  /// Overpass QL for the objects of [category] inside [bounds].
  static String query(PoiCategory category, GeoBounds bounds) {
    String coordinate(double value) => value.toStringAsFixed(5);
    final bbox = [
      bounds.south,
      bounds.west,
      bounds.north,
      bounds.east,
    ].map(coordinate).join(',');
    final statements = [
      for (final MapEntry(:key, :value) in category.tags.entries)
        'nwr["$key"~"^(${value.join('|')})\$"];',
    ].join();
    return '[out:json][timeout:$_timeoutSeconds][bbox:$bbox];'
        '($statements);'
        'out tags center ${PlacesRepository.maxResults};';
  }

  /// Parses an Overpass JSON response, skipping unusable elements.
  static List<Poi> parse(Map<String, dynamic> body) {
    final elements = body['elements'];
    final remark = body['remark'];
    // Overpass reports timeouts and memory limits in a remark, sometimes
    // with partial results; an empty partial answer is not "no places".
    if (remark is String && remark.contains('error')) {
      if (elements is! List || elements.isEmpty) {
        throw ServiceException(ServiceFailure.unavailable, remark);
      }
    }
    if (elements is! List) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
    return [for (final element in elements) ?_poi(element)];
  }

  static Poi? _poi(Object? element) {
    if (element is! Map) return null;
    final type = OsmElementType.values.asNameMap()[element['type']];
    final id = element['id'];
    if (type == null || id is! int || id <= 0) return null;

    final position = type == OsmElementType.node ? element : element['center'];
    if (position is! Map) return null;
    final lat = position['lat'];
    final lon = position['lon'];
    final point = GeoPoint.tryCreate(
      lat is num ? lat : null,
      lon is num ? lon : null,
    );
    if (point == null) return null;

    final rawTags = element['tags'];
    final tags = <String, String>{
      if (rawTags is Map)
        for (final MapEntry(:key, :value) in rawTags.entries)
          if (key is String && value is String && value.trim().isNotEmpty)
            key: value.trim(),
    };

    return Poi(
      ref: OsmRef(type, id),
      point: point,
      name: tags['name:it'] ?? tags['name'],
      category: PlaceCategory.firstLabel([
        tags['amenity'],
        tags['shop'],
        tags['tourism'],
        tags['leisure'],
        tags['railway'],
        tags['highway'],
      ]),
      address: _address(tags),
      openingHours: tags['opening_hours'],
      website: PlaceLinks.website(tags['website'] ?? tags['contact:website']),
      phone: PlaceLinks.phone(tags['phone'] ?? tags['contact:phone']),
      cuisine: tags['cuisine']
          ?.split(';')
          .map((value) => value.trim().replaceAll('_', ' '))
          .where((value) => value.isNotEmpty)
          .join(', '),
      wheelchair: WheelchairAccess.values.asNameMap()[tags['wheelchair']],
    );
  }

  /// "Via Sparano da Bari, 5 · Bari", from whichever parts are tagged.
  static String? _address(Map<String, String> tags) {
    final street = tags['addr:street'];
    final number = tags['addr:housenumber'];
    final city = tags['addr:city'];
    final line = street == null
        ? null
        : (number == null ? street : '$street, $number');
    final parts = [?line, ?city];
    return parts.isEmpty ? null : parts.join(' · ');
  }

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

/// The configured places source, or null when discovery is disabled.
final placesRepositoryProvider = Provider<PlacesRepository?>((ref) {
  const endpoint = AppConfig.placesUrl;
  if (endpoint.isEmpty) return null;
  return OverpassPlacesRepository(
    ref.watch(jsonHttpClientProvider),
    endpoint: endpoint,
    minInterval: AppConfig.placesMinInterval,
  );
});
