import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/features/transit/data/transit_store.dart';
import 'package:navia/features/transit/presentation/transit_controller.dart';
import 'package:navia/features/transit/presentation/transit_line_banner.dart';
import 'package:navia/features/transit/presentation/transit_stop_section.dart';
import 'package:navia/shared/models/geo_point.dart';

import '../features/transit/gtfs_fixture.dart';
import 'widget_test_harness.dart';

void main() {
  testWidgets('downloads AMTAB timetables from a stop and lists its buses', (
    tester,
  ) async {
    final feed = zipOf(tinyFeed(DateTime.now()));
    var requests = 0;
    final mock = MockClient((request) async {
      requests++;
      return http.Response.bytes(feed, 200);
    });
    final dir = Directory.systemTemp.createTempSync('navia_transit_w_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final container = await pumpNaviaWidget(
      tester,
      const Scaffold(
        body: Column(
          children: [
            TransitLineBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: TransitStopSection(
                  // A few meters from the stop, like a map label.
                  point: GeoPoint(latitude: 41.12010, longitude: 16.87005),
                  category: 'Fermata autobus',
                ),
              ),
            ),
          ],
        ),
      ),
      overrides: [
        transitStoreProvider.overrideWithValue(
          TransitStore(
            dir,
            mock,
            url: Uri.parse('https://amtab.example/g.zip'),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scarica orari'));
    await tester.pumpAndSettle();
    expect(find.text('Scaricare gli orari dei bus AMTAB?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(requests, 0);

    await tester.tap(find.text('Scarica orari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scarica'));
    for (var i = 0; i < 500; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.text('Stazione').evaluate().isNotEmpty) break;
    }

    expect(requests, 1);
    expect(find.text('PROSSIMI BUS · PICCINNI, TEATRO'), findsOneWidget);
    expect(find.text('Stazione'), findsWidgets);

    await tester.tap(find.byTooltip('Mostra la linea 02/'));
    // The line's shapes are read from storage.
    for (var i = 0; i < 500; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (container.read(shownLineScheduleProvider) != null) break;
    }
    expect(container.read(transitLineProvider), 0);
    expect(container.read(shownLineScheduleProvider)?.shapes, hasLength(1));
    expect(find.text('Nascondi linea'), findsOneWidget);

    // The line has its own banner, which alone can hide it.
    expect(find.text('Piscine - S.Anna'), findsOneWidget);
    expect(find.textContaining('in servizio'), findsOneWidget);
    await tester.tap(find.byTooltip('Nascondi linea'));
    await tester.pump();
    expect(container.read(transitLineProvider), isNull);
    expect(find.text('Piscine - S.Anna'), findsNothing);
  });
}
