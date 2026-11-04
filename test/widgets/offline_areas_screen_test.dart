import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/offline_areas/offline_areas_screen.dart';
import 'package:navia/features/offline_maps/data/map_data_client.dart';
import 'package:navia/features/offline_maps/presentation/offline_maps_controller.dart';
import 'package:navia/features/places/data/place_data_client.dart';
import 'package:navia/features/places/presentation/offline_places_controller.dart';

import 'widget_test_harness.dart';

void main() {
  testWidgets('downloads the chosen parts of a zone only after consent', (
    tester,
  ) async {
    final mapBytes = utf8.encode('PMTiles archive');
    final placeBytes = gzip.encode(
      utf8.encode(
        '${jsonEncode({
          'id': 'node/1',
          'lat': 41.12,
          'lon': 16.87,
          'tags': {'amenity': 'pharmacy'},
        })}\n',
      ),
    );
    var mapRequests = 0;
    var placeRequests = 0;
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('map-data/manifest.json')) {
        return http.Response(
          jsonEncode({
            'version': 1,
            'regions': [
              {
                'id': 'sud',
                'name': 'Sud',
                'detail': 'Puglia',
                'file': 'map-sud.pmtiles',
                'bytes': mapBytes.length,
                'sha256': sha256.convert(mapBytes).toString(),
                'minzoom': 0,
                'maxzoom': 14,
                'bbox': [37.9, 13.0, 42.9, 18.5],
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('places-data/manifest.json')) {
        return http.Response(
          jsonEncode({
            'version': 1,
            'regions': [
              {
                'id': 'sud',
                'name': 'Sud',
                'detail': 'Puglia',
                'file': 'places-sud.jsonl.gz',
                'bytes': placeBytes.length,
                'sha256': sha256.convert(placeBytes).toString(),
                'count': 126088,
                'bbox': [37.9, 13.0, 42.9, 18.5],
              },
            ],
          }),
          200,
        );
      }
      if (path.contains('map-data')) {
        mapRequests++;
        return http.Response.bytes(mapBytes, 200);
      }
      placeRequests++;
      return http.Response.bytes(placeBytes, 200);
    });
    final json = JsonHttpClient(mock, userAgent: 'Navia/test');

    final container = await pumpNaviaWidget(
      tester,
      const OfflineAreasScreen(),
      overrides: [
        mapDataClientProvider.overrideWithValue(
          MapDataClient(
            mock,
            json,
            baseUrl: 'https://data.example/map-data',
            userAgent: 'Navia/test',
          ),
        ),
        placeDataClientProvider.overrideWithValue(
          PlaceDataClient(
            mock,
            json,
            baseUrl: 'https://data.example/places-data',
            userAgent: 'Navia/test',
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    // One card for the zone, with both parts.
    expect(find.text('Sud'), findsOneWidget);
    expect(find.textContaining('Mappa:'), findsOneWidget);
    expect(find.textContaining('126.088 luoghi'), findsOneWidget);

    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    expect(find.text('Scaricare la zona Sud?'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    // Cancelling the consent dialog downloads nothing.
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(mapRequests + placeRequests, 0);

    // Only the places: the map is unchecked.
    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Mappa: 1 kB'));
    await tester.pump();
    await tester.tap(find.text('Scarica').last);
    await _settleIo(
      tester,
      () => container.read(offlinePlacesProvider).installed.isNotEmpty,
    );

    expect(placeRequests, 1);
    expect(mapRequests, 0);
    expect(find.textContaining('Luoghi: sul dispositivo dal'), findsOneWidget);

    // The map is still offered.
    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.text('Scarica').last);
    await _settleIo(
      tester,
      () => container.read(offlineMapsProvider).installed.isNotEmpty,
    );
    expect(mapRequests, 1);
    expect(find.text('Scarica'), findsNothing);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare i dati della zona Sud?'), findsOneWidget);
    await tester.tap(find.text('Elimina').last);
    await _settleIo(
      tester,
      () =>
          container.read(offlineMapsProvider).installed.isEmpty &&
          container.read(offlinePlacesProvider).installed.isEmpty,
    );

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
