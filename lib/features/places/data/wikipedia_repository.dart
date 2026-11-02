import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_point.dart';
import '../domain/poi.dart';

/// The Wikipedia summary of a place.
@immutable
class PlaceArticle {
  const PlaceArticle({
    required this.title,
    required this.extract,
    required this.url,
    required this.language,
    this.thumbnail,
  });

  final String title;

  /// The first paragraph of the article, as plain text.
  final String extract;

  /// The article, to read it in full.
  final Uri url;

  /// Wikipedia language edition, e.g. "it".
  final String language;

  /// A small image chosen by Wikipedia for the article.
  final Uri? thumbnail;
}

/// Reads the Wikipedia summary of places tagged with `wikipedia` or
/// `wikidata`, preferring the Italian edition; places without those tags
/// are looked up by name among the Italian articles nearby.
///
/// It is called only when the user opens a place card, and sends Wikimedia
/// the article title or Wikidata id, or the place's position rounded to
/// about 100 m.
class WikipediaRepository {
  WikipediaRepository(this._client);

  final JsonHttpClient _client;

  static const _preferred = ['it', 'en'];

  /// An article within this distance of the place, with a matching title,
  /// is about it.
  static const nearbyRadiusMeters = 250;

  /// The article about the place named [name] at [point]: the one linked by
  /// [place]'s tags, else a nearby Italian article with a matching title.
  Future<PlaceArticle?> articleFor({
    Poi? place,
    String? name,
    required GeoPoint point,
  }) async {
    if (place != null && (place.wikipedia != null || place.wikidata != null)) {
      final tagged = await article(place);
      if (tagged != null) return tagged;
    }
    final label = name ?? place?.name;
    if (label == null) return null;
    final title = await _nearbyTitle(label, point);
    return title == null ? null : _summary('it', title);
  }

  Future<PlaceArticle?> article(Poi place) async {
    final page = await _page(place);
    if (page == null) return null;
    final (language, title) = page;
    return _summary(language, title);
  }

  Future<PlaceArticle?> _summary(String language, String title) async {
    final uri = Uri.https(
      '$language.wikipedia.org',
      '/api/rest_v1/page/summary/${title.replaceAll(' ', '_')}',
    );
    final response = await _client.getJson(uri);
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 400) {
      throw ServiceException(ServiceFailure.unavailable, response.statusCode);
    }
    return parseSummary(response.body, language);
  }

  /// The language and title of the article to show, if any.
  Future<(String, String)?> _page(Poi place) async {
    final tagged = place.wikipedia;
    String? language;
    String? title;
    if (tagged != null) {
      final separator = tagged.indexOf(':');
      language = tagged.substring(0, separator);
      title = tagged.substring(separator + 1);
      if (language == 'it') return (language, title);
    }
    final wikidata = place.wikidata;
    if (wikidata != null) {
      final sitelinks = await _sitelinks(wikidata);
      for (final preferred in _preferred) {
        final linked = sitelinks['${preferred}wiki'];
        if (linked != null) return (preferred, linked);
      }
    }
    return language != null && title != null ? (language, title) : null;
  }

  Future<String?> _nearbyTitle(String name, GeoPoint point) async {
    // Rounded to about 100 m; the larger radius covers the rounding.
    final uri = Uri.https('it.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'list': 'geosearch',
      'gscoord':
          '${point.latitude.toStringAsFixed(3)}|'
          '${point.longitude.toStringAsFixed(3)}',
      'gsradius': '${nearbyRadiusMeters + 150}',
      'gslimit': '30',
    });
    final response = await _client.getJson(uri);
    if (response.statusCode >= 400) {
      throw ServiceException(ServiceFailure.unavailable, response.statusCode);
    }
    return matchingTitle(response.body, name, point);
  }

  /// The nearest geosearch result within [nearbyRadiusMeters] of [point]
  /// whose title names the same thing as [name].
  @visibleForTesting
  static String? matchingTitle(
    Map<String, dynamic> body,
    String name,
    GeoPoint point,
  ) {
    final query = body['query'];
    final results = query is Map ? query['geosearch'] : null;
    if (results is! List) return null;
    final wanted = words(name);
    String? best;
    var bestDistance = double.infinity;
    for (final result in results) {
      if (result is! Map) continue;
      final title = result['title'];
      final lat = result['lat'];
      final lon = result['lon'];
      final at = GeoPoint.tryCreate(
        lat is num ? lat : null,
        lon is num ? lon : null,
      );
      if (title is! String || at == null) continue;
      final distance = point.distanceTo(at);
      if (distance > nearbyRadiusMeters || distance >= bestDistance) continue;
      if (!sameName(wanted, words(title))) continue;
      best = title;
      bestDistance = distance;
    }
    return best;
  }

  static const _stopWords = {
    'a', 'al', 'alla', 'd', 'da', 'dal', 'dalla', 'de', 'dei', 'del', //
    'della', 'delle', 'degli', 'di', 'e', 'gli', 'i', 'il', 'in', 'l', //
    'la', 'le', 'lo',
  };

  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'è': 'e', 'é': 'e', //
    'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'ú': 'u', //
    'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n',
  };

  /// The significant words of a name, lowercase and without accents or a
  /// trailing "(disambiguation)".
  @visibleForTesting
  static Set<String> words(String text) {
    final plain = text
        .toLowerCase()
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .split('')
        .map((c) => _accents[c] ?? c)
        .join();
    return {
      for (final word in plain.split(RegExp('[^a-z0-9]+')))
        if (word.isNotEmpty && !_stopWords.contains(word)) word,
    };
  }

  /// Whether two names, as significant words, name the same thing: the
  /// same words, or one with all the words of the other when that has at
  /// least two, so "Petruzzelli" never matches "Farmacia Petruzzelli".
  @visibleForTesting
  static bool sameName(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a.length == b.length) return a.containsAll(b);
    final (shorter, longer) = a.length < b.length ? (a, b) : (b, a);
    return shorter.length >= 2 && longer.containsAll(shorter);
  }

  Future<Map<String, String>> _sitelinks(String id) async {
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': id,
      'props': 'sitelinks',
      'sitefilter': _preferred.map((l) => '${l}wiki').join('|'),
      'format': 'json',
    });
    final response = await _client.getJson(uri);
    return parseSitelinks(response.body, id);
  }

  @visibleForTesting
  static Map<String, String> parseSitelinks(
    Map<String, dynamic> body,
    String id,
  ) {
    final entities = body['entities'];
    final entity = entities is Map ? entities[id] : null;
    final sitelinks = entity is Map ? entity['sitelinks'] : null;
    if (sitelinks is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in sitelinks.entries)
        if (key is String && value is Map && value['title'] is String)
          key: value['title'] as String,
    };
  }

  @visibleForTesting
  static PlaceArticle? parseSummary(
    Map<String, dynamic> body,
    String language,
  ) {
    // Disambiguation pages list homonyms, not this place.
    if (body['type'] == 'disambiguation') return null;
    final title = body['title'];
    final extract = body['extract'];
    final urls = body['content_urls'];
    final mobile = urls is Map ? urls['mobile'] : null;
    final page = mobile is Map ? mobile['page'] : null;
    if (title is! String ||
        extract is! String ||
        extract.trim().isEmpty ||
        page is! String) {
      return null;
    }
    final url = Uri.tryParse(page);
    if (url == null || url.scheme != 'https') return null;
    final thumbnail = body['thumbnail'];
    final source = thumbnail is Map ? thumbnail['source'] : null;
    final image = source is String ? Uri.tryParse(source) : null;
    return PlaceArticle(
      title: title,
      extract: extract.trim(),
      url: url,
      language: language,
      thumbnail: image != null && image.scheme == 'https' ? image : null,
    );
  }
}

final wikipediaRepositoryProvider = Provider<WikipediaRepository>(
  (ref) => WikipediaRepository(ref.watch(jsonHttpClientProvider)),
);

/// A place card: the OpenStreetMap place, if known, and the name and
/// position of the selection.
typedef PlaceArticleQuery = ({Poi? place, String? name, GeoPoint point});

/// Whether [query] links or names something to look up.
bool hasArticleLookup(PlaceArticleQuery query) =>
    query.name != null ||
    query.place?.name != null ||
    query.place?.wikipedia != null ||
    query.place?.wikidata != null;

/// The article of a place card, loaded when the card is shown.
final placeArticleProvider = FutureProvider.autoDispose
    .family<PlaceArticle?, PlaceArticleQuery>((ref, query) {
      if (!hasArticleLookup(query)) return Future.value();
      return ref
          .read(wikipediaRepositoryProvider)
          .articleFor(place: query.place, name: query.name, point: query.point);
    });
