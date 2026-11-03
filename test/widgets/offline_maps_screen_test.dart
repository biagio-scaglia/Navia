import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/offline_maps/data/map_data_client.dart';
import 'package:navia/features/offline_maps/presentation/offline_maps_controller.dart';
import 'package:navia/features/offline_maps/presentation/offline_maps_screen.dart';

import 'widget_test_harness.dart';

void main() {
  testWidgets('downloads a map only after consent, then deletes it', (
    tester,
  ) async {
    final bytes = utf8.encode('PMTiles archive');
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
                'file': 'map-sud.pmtiles',
                'bytes': bytes.length,
                'sha256': sha256.convert(bytes).toString(),
                'minzoom': 0,
                'maxzoom': 14,
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
      const OfflineMapsScreen(),
      overrides: [
        mapDataClientProvider.overrideWithValue(
          MapDataClient(
            mock,
            JsonHttpClient(mock, userAgent: 'Navia/test'),
            baseUrl: 'https://data.example/map-data',
            userAgent: 'Navia/test',
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Mappe offline'), findsOneWidget);
    expect(find.text('Sud'), findsOneWidget);

    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    expect(find.text('Scaricare la zona Sud?'), findsOneWidget);
    expect(find.textContaining('Wi-Fi'), findsWidgets);

    // Cancelling the consent dialog downloads nothing.
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(dataRequests, 0);

    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scarica').last);
    await _settleIo(
      tester,
      () => container.read(offlineMapsProvider).installed.isNotEmpty,
    );

    expect(dataRequests, 1);
    expect(find.textContaining('Scaricata il'), findsOneWidget);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la mappa della zona Sud?'), findsOneWidget);
    await tester.tap(find.text('Elimina').last);
    await _settleIo(
      tester,
      () => container.read(offlineMapsProvider).installed.isEmpty,
    );

    expect(find.text('Scarica'), findsOneWidget);
  });
}

/// Lets real asynchronous work progress until [done], pumping frames.
Future<void> _settleIo(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 1000 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}
