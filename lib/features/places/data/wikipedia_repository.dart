import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
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
/// `wikidata`, preferring the Italian edition.
///
/// It is called only when the user opens a place card, and sends Wikimedia
/// only the article title or Wikidata id.
class WikipediaRepository {
  WikipediaRepository(this._client);

  final JsonHttpClient _client;

  static const _preferred = ['it', 'en'];

  Future<PlaceArticle?> article(Poi place) async {
    final page = await _page(place);
    if (page == null) return null;
    final (language, title) = page;
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

/// The article of [Poi], loaded when a place card is shown.
final placeArticleProvider = FutureProvider.autoDispose
    .family<PlaceArticle?, Poi>((ref, place) {
      if (place.wikipedia == null && place.wikidata == null) {
        return Future.value();
      }
      return ref.read(wikipediaRepositoryProvider).article(place);
    });
