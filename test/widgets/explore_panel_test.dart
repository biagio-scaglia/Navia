import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/discover/discover.dart';
import 'package:navia/features/navigation/presentation/widgets/explore_panel.dart';
import 'package:navia/shared/models/geo_point.dart';

import 'widget_test_harness.dart';

class _Articles extends NearbyArticlesRepository {
  _Articles()
    : super(
        JsonHttpClient(
          MockClient((_) async => http.Response('', 500)),
          userAgent: '',
        ),
        endpoint: '',
      );

  GeoPoint? searched;

  @override
  Future<List<NearbyArticle>> near(GeoPoint center) async {
    searched = center;
    return [
      NearbyArticle(
        title: 'Teatro Petruzzelli',
        point: const GeoPoint(latitude: 41.1236, longitude: 16.8732),
        url: Uri.parse('https://it.wikipedia.org/wiki/Teatro_Petruzzelli'),
        distanceMeters: 560,
        description: 'teatro di Bari',
      ),
    ];
  }
}

void main() {
  testWidgets('switches tabs and discovers articles near the map center', (
    tester,
  ) async {
    final articles = _Articles();
    NearbyArticle? focused;
    await pumpNaviaWidget(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ExplorePanel(
            goTab: const Text('Dove vuoi andare?'),
            mapCenter: () async =>
                const GeoPoint(latitude: 41.12, longitude: 16.87),
            onFocus: (article) => focused = article,
          ),
        ),
      ),
      overrides: [nearbyArticlesRepositoryProvider.overrideWithValue(articles)],
    );

    expect(find.text('Dove vuoi andare?'), findsOneWidget);

    await tester.tap(find.text('Scopri'));
    await tester.pumpAndSettle();
    expect(find.text('Dove vuoi andare?'), findsNothing);
    await tester.tap(find.text('Scopri qui intorno'));
    await tester.pumpAndSettle();

    expect(
      articles.searched,
      const GeoPoint(latitude: 41.12, longitude: 16.87),
    );
    expect(find.text('Teatro Petruzzelli'), findsOneWidget);
    expect(find.text('teatro di Bari · 560 m'), findsOneWidget);
    await tester.tap(find.text('Teatro Petruzzelli'));
    expect(focused?.title, 'Teatro Petruzzelli');

    await tester.tap(find.text('15 min'));
    await tester.pumpAndSettle();
    expect(find.text('Mostra sulla mappa'), findsOneWidget);
    expect(find.text('A piedi'), findsOneWidget);
  });
}
