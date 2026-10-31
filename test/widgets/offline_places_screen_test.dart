import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/places/data/fuel_prices_store.dart';
import 'package:navia/features/places/data/place_data_client.dart';
import 'package:navia/features/places/presentation/offline_places_controller.dart';
import 'package:navia/features/places/presentation/offline_places_screen.dart';

import 'widget_test_harness.dart';

void main() {
  testWidgets('downloads a region only after consent, then deletes it', (
    tester,
  ) async {
    final bytes = gzip.encode(
      utf8.encode(
        '${jsonEncode({
          'id': 'node/1',
          'lat': 41.12,
          'lon': 16.87,
          'tags': {'amenity': 'pharmacy'},
        })}\n',
      ),
    );
    var dataRequests = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('manifest.json')) {
        return http.Response(
          jsonEncode({
            'version': 1,
            'regions': [
              {
                'id': 'sud',
                'name': 'Sud',
                'detail': 'Puglia',
                'file': 'places-sud.jsonl.gz',
                'bytes': bytes.length,
                'sha256': sha256.convert(bytes).toString(),
                'count': 126088,
                'bbox': [37.9, 13.0, 42.9, 18.5],
              },
            ],
          }),
          200,
        );
      }
      dataRequests++;
      return http.Response.bytes(bytes, 200);
    });

    final container = await pumpNaviaWidget(
      tester,
      const OfflinePlacesScreen(),
      overrides: [
        // Fuel prices have their own card and tests.
        fuelPricesStoreProvider.overrideWithValue(null),
        placeDataClientProvider.overrideWithValue(
          PlaceDataClient(
            mock,
            JsonHttpClient(mock, userAgent: 'Navia/test'),
            baseUrl: 'https://data.example/places-data',
            userAgent: 'Navia/test',
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Sud'), findsOneWidget);
    expect(find.textContaining('126.088 luoghi'), findsOneWidget);

    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    expect(find.text('Scaricare la zona Sud?'), findsOneWidget);
    expect(dataRequests, 0);

    // Cancelling the consent dialog downloads nothing.
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(dataRequests, 0);

    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scarica').last);
    // File access and the import isolate run on the real event loop.
    await _settleIo(
      tester,
      () => container.read(offlinePlacesProvider).installed.isNotEmpty,
    );

    expect(dataRequests, 1);
    expect(find.textContaining('Scaricata il'), findsOneWidget);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina').last);
    await _settleIo(
      tester,
      () => container.read(offlinePlacesProvider).installed.isEmpty,
    );

    expect(container.read(offlinePlacesProvider).installed, isEmpty);
    expect(find.text('Scarica'), findsOneWidget);
  });
}

/// Lets real asynchronous work progress until [done], pumping frames.
Future<void> _settleIo(WidgetTester tester, bool Function() done) async {
  // Up to 10 seconds: file access is slow on a busy machine.
  for (var i = 0; i < 1000 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
