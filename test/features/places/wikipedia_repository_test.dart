import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/places/data/osm_poi_parser.dart';
import 'package:navia/features/places/data/wikipedia_repository.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/shared/models/geo_point.dart';

const _point = GeoPoint(latitude: 41.1236, longitude: 16.8732);

Poi _place({String? wikipedia, String? wikidata}) => Poi(
  ref: const OsmRef(OsmElementType.way, 1),
  point: _point,
  wikipedia: wikipedia,
  wikidata: wikidata,
);

Map<String, dynamic> _summary(String title) => {
  'type': 'standard',
  'title': title,
  'extract': 'Il Teatro Petruzzelli è il principale teatro di Bari.',
  'content_urls': {
    'mobile': {'page': 'https://it.m.wikipedia.org/wiki/$title'},
  },
  'thumbnail': {'source': 'https://upload.wikimedia.org/thumb.jpg'},
};

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

WikipediaRepository _repository(MockClientHandler handler) =>
    WikipediaRepository(
      JsonHttpClient(MockClient(handler), userAgent: 'Navia/test'),
    );

void main() {
  test('the parser keeps valid wikipedia and wikidata tags only', () {
    final place = OsmPoiParser.fromTags(
      const OsmRef(OsmElementType.node, 1),
      _point,
      {'wikipedia': 'it:Teatro Petruzzelli', 'wikidata': 'Q1131569'},
    );
    expect(place.wikipedia, 'it:Teatro Petruzzelli');
    expect(place.wikidata, 'Q1131569');

    final invalid = OsmPoiParser.fromTags(
      const OsmRef(OsmElementType.node, 2),
      _point,
      {'wikipedia': 'Teatro', 'wikidata': '1131569'},
    );
    expect(invalid.wikipedia, isNull);
    expect(invalid.wikidata, isNull);
  });

  test('reads the Italian summary of a tagged article', () async {
    final requests = <Uri>[];
    final repository = _repository((request) async {
      requests.add(request.url);
      return _json(_summary('Teatro_Petruzzelli'));
    });

    final article = await repository.article(
      _place(wikipedia: 'it:Teatro Petruzzelli'),
    );

    expect(requests.single.host, 'it.wikipedia.org');
    expect(requests.single.path, endsWith('/summary/Teatro_Petruzzelli'));
    expect(article?.extract, startsWith('Il Teatro Petruzzelli'));
    expect(article?.thumbnail?.host, 'upload.wikimedia.org');
    expect(article?.language, 'it');
  });

  test('finds the Italian article through Wikidata', () async {
    final repository = _repository((request) async {
      if (request.url.host == 'www.wikidata.org') {
        expect(request.url.queryParameters['ids'], 'Q1131569');
        return _json({
          'entities': {
            'Q1131569': {
              'sitelinks': {
                'enwiki': {'title': 'Petruzzelli Theatre'},
                'itwiki': {'title': 'Teatro Petruzzelli'},
              },
            },
          },
        });
      }
      expect(request.url.host, 'it.wikipedia.org');
      return _json(_summary('Teatro_Petruzzelli'));
    });

    final article = await repository.article(
      _place(wikipedia: 'en:Petruzzelli Theatre', wikidata: 'Q1131569'),
    );
    expect(article?.language, 'it');
  });

  test('ignores disambiguation pages and missing articles', () async {
    expect(
      WikipediaRepository.parseSummary({
        ..._summary('Petruzzelli'),
        'type': 'disambiguation',
      }, 'it'),
      isNull,
    );
    final missing = _repository((_) async => _json({'type': 'not_found'}, 404));
    expect(await missing.article(_place(wikipedia: 'it:Nessuna')), isNull);
  });

  group('places without tags', () {
    Map<String, dynamic> nearby(List<(String, double, double)> pages) => {
      'query': {
        'geosearch': [
          for (final (title, lat, lon) in pages)
            {'title': title, 'lat': lat, 'lon': lon},
        ],
      },
    };

    test('match names by their significant words', () {
      bool same(String a, String b) => WikipediaRepository.sameName(
        WikipediaRepository.words(a),
        WikipediaRepository.words(b),
      );
      expect(same('Teatro Petruzzelli', 'Teatro Petruzzelli'), isTrue);
      expect(
        same('Castello Normanno-Svevo', 'Castello normanno-svevo (Bari)'),
        isTrue,
      );
      expect(same('Basilica San Nicola', 'Basilica di San Nicola'), isTrue);
      expect(same('Città Vecchia', 'Citta vecchia'), isTrue);
      expect(same('Petruzzelli', 'Farmacia Petruzzelli'), isFalse);
      expect(same('Bar', 'Bari'), isFalse);
    });

    test('pick the nearest matching article within the radius', () {
      final body = nearby([
        ('Bari', 41.1236, 16.8732),
        ('Teatro Petruzzelli (edificio)', 41.13, 16.88), // about 900 m away
        ('Teatro Petruzzelli', 41.1240, 16.8735),
      ]);
      expect(
        WikipediaRepository.matchingTitle(body, 'Teatro Petruzzelli', _point),
        'Teatro Petruzzelli',
      );
      expect(
        WikipediaRepository.matchingTitle(body, 'Farmacia Centrale', _point),
        isNull,
      );
    });

    test('look up a named place nearby, rounding its position', () async {
      final requests = <Uri>[];
      final repository = _repository((request) async {
        requests.add(request.url);
        if (request.url.path == '/w/api.php') {
          return _json(nearby([('Teatro Petruzzelli', 41.1240, 16.8735)]));
        }
        return _json(_summary('Teatro_Petruzzelli'));
      });

      final article = await repository.articleFor(
        name: 'Teatro Petruzzelli',
        point: _point,
      );
      expect(article?.title, 'Teatro_Petruzzelli');
      expect(requests.first.queryParameters['gscoord'], '41.124|16.873');
    });

    test('skip the search for unnamed points', () async {
      final repository = _repository((_) async => fail('no request'));
      expect(await repository.articleFor(point: _point), isNull);
    });
  });
}
