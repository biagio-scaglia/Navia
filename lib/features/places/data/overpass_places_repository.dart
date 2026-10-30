import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_bounds.dart';
import '../../../shared/models/geo_point.dart';
import '../domain/places_repository.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';
import 'osm_poi_parser.dart';

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
    this.retryDelays = const [],
  });

  final JsonHttpClient _client;
  final String endpoint;

  /// Minimum spacing between requests, to stay a light user of the server.
  final Duration minInterval;

  /// Waits before each new attempt when the server says it is busy (429,
  /// 502, 504), growing as the server asks. Timeouts are not retried: the
  /// request already waited in the server queue.
  final List<Duration> retryDelays;

  final Stopwatch _sinceLastRequest = Stopwatch();

  /// Server-side time limit, in seconds; small areas answer much faster.
  static const _timeoutSeconds = 15;

  @override
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds) async {
    final uri = Uri.parse(
      endpoint,
    ).replace(queryParameters: {'data': query(category, bounds)});
    for (var attempt = 0; ; attempt++) {
      await _respectRateLimit();
      try {
        return await _fetch(uri);
      } on ServiceException catch (error) {
        final busy =
            error.failure == ServiceFailure.unavailable ||
            error.failure == ServiceFailure.rateLimited;
        if (!busy || attempt >= retryDelays.length) rethrow;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  Future<List<Poi>> _fetch(Uri uri) async {
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

    return OsmPoiParser.fromTags(
      OsmRef(type, id),
      point,
      OsmPoiParser.tags(element['tags']),
    );
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

/// The configured online places source, or null when it is disabled.
final onlinePlacesRepositoryProvider = Provider<PlacesRepository?>((ref) {
  const endpoint = AppConfig.placesUrl;
  if (endpoint.isEmpty) return null;
  return OverpassPlacesRepository(
    // Longer than the server-side limit, so that its answer can arrive.
    ref
        .watch(jsonHttpClientProvider)
        .withTimeout(AppConfig.placesRequestTimeout),
    endpoint: endpoint,
    minInterval: AppConfig.placesMinInterval,
    retryDelays: AppConfig.placesRetryDelays,
  );
});
