import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/network/json_http_client.dart';
import '../../shared/models/geo_point.dart';

/// A Wikipedia article about something near the searched point.
@immutable
class NearbyArticle {
  const NearbyArticle({
    required this.title,
    required this.point,
    required this.url,
    required this.distanceMeters,
    this.description,
    this.thumbnail,
  });

  final String title;
  final GeoPoint point;
  final Uri url;
  final double distanceMeters;

  /// Short description from Wikidata, e.g. "chiesa di Bari".
  final String? description;
  final Uri? thumbnail;
}

/// Finds Wikipedia articles with coordinates near a point (geosearch),
/// with their image and short description, in the Italian edition.
class NearbyArticlesRepository {
  NearbyArticlesRepository(this._client, {required this.endpoint});

  final JsonHttpClient _client;
  final String endpoint;

  /// Search radius, in meters (the API allows up to 10 km).
  static const radiusMeters = 3000;
  static const limit = 25;

  /// Titles of administrative areas, which describe the whole town rather
  /// than something to see there.
  static final _administrative = RegExp(
    r'^(Provincia|Città metropolitana|Regione|Arcidiocesi|Diocesi) ',
  );

  Future<List<NearbyArticle>> near(GeoPoint center) async {
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'action': 'query',
        'format': 'json',
        'formatversion': '2',
        'generator': 'geosearch',
        'ggscoord':
            '${center.latitude.toStringAsFixed(4)}|'
            '${center.longitude.toStringAsFixed(4)}',
        'ggsradius': '$radiusMeters',
        'ggslimit': '$limit',
        'prop': 'coordinates|pageimages|description|info',
        'inprop': 'url',
        'piprop': 'thumbnail',
        'pithumbsize': '240',
      },
    );
    final response = await _client.getJson(uri);
    if (response.statusCode >= 400) {
      throw ServiceException(ServiceFailure.unavailable, response.statusCode);
    }
    return parse(response.body, center);
  }

  @visibleForTesting
  static List<NearbyArticle> parse(Map<String, dynamic> body, GeoPoint center) {
    final query = body['query'];
    final pages = query is Map ? query['pages'] : null;
    if (pages is! List) return const [];
    final articles = <NearbyArticle>[];
    for (final page in pages) {
      if (page is! Map) continue;
      final title = page['title'];
      final coordinates = page['coordinates'];
      final url = Uri.tryParse('${page['fullurl']}');
      if (title is! String || _administrative.hasMatch(title)) continue;
      if (coordinates is! List || coordinates.isEmpty) continue;
      final first = coordinates.first;
      if (first is! Map) continue;
      final lat = first['lat'];
      final lon = first['lon'];
      final point = GeoPoint.tryCreate(
        lat is num ? lat : null,
        lon is num ? lon : null,
      );
      if (point == null || url == null || url.scheme != 'https') continue;
      final thumbnail = page['thumbnail'];
      final source = thumbnail is Map ? thumbnail['source'] : null;
      final image = source is String ? Uri.tryParse(source) : null;
      final description = page['description'];
      articles.add(
        NearbyArticle(
          title: title,
          point: point,
          url: url,
          distanceMeters: center.distanceTo(point),
          description: description is String && description.trim().isNotEmpty
              ? description.trim()
              : null,
          thumbnail: image != null && image.scheme == 'https' ? image : null,
        ),
      );
    }
    articles.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return articles;
  }
}

enum DiscoverStatus { idle, loading, ready, failed }

@immutable
class DiscoverState {
  const DiscoverState({
    this.status = DiscoverStatus.idle,
    this.articles = const [],
    this.failure,
  });

  final DiscoverStatus status;
  final List<NearbyArticle> articles;
  final ServiceFailure? failure;
}

/// "Scopri qui intorno": searches only when the user asks.
class DiscoverController extends Notifier<DiscoverState> {
  int _generation = 0;

  @override
  DiscoverState build() => const DiscoverState();

  Future<void> search(GeoPoint center) async {
    final repository = ref.read(nearbyArticlesRepositoryProvider);
    if (repository == null) return;
    final generation = ++_generation;
    state = DiscoverState(
      status: DiscoverStatus.loading,
      articles: state.articles,
    );
    try {
      final articles = await repository.near(center);
      if (!ref.mounted || generation != _generation) return;
      state = DiscoverState(status: DiscoverStatus.ready, articles: articles);
    } on ServiceException catch (error) {
      logServiceError('discover', error);
      if (!ref.mounted || generation != _generation) return;
      state = DiscoverState(
        status: DiscoverStatus.failed,
        failure: error.failure,
      );
    }
  }
}

final nearbyArticlesRepositoryProvider = Provider<NearbyArticlesRepository?>((
  ref,
) {
  const endpoint = AppConfig.wikipediaApiUrl;
  if (endpoint.isEmpty) return null;
  return NearbyArticlesRepository(
    ref.watch(jsonHttpClientProvider),
    endpoint: endpoint,
  );
});

final discoverProvider = NotifierProvider<DiscoverController, DiscoverState>(
  DiscoverController.new,
);
