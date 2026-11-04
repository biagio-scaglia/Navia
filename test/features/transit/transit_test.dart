import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:navia/features/transit/data/gtfs_import.dart';
import 'package:navia/features/transit/data/transit_store.dart';
import 'package:navia/features/transit/data/zip_reader.dart';
import 'package:navia/features/transit/domain/schedule.dart';
import 'package:navia/features/transit/domain/transit.dart';
import 'package:navia/shared/models/geo_point.dart';

import 'gtfs_fixture.dart';

void main() {
  final today = DateTime(2026, 11, 4);
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('navia_transit_'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('ZipReader', () {
    test('reads stored and deflated entries', () {
      for (final deflate in [true, false]) {
        final zip = ZipReader(zipOf({'a.txt': 'ciao, Bari'}, deflate: deflate));
        expect(zip.readText('a.txt'), 'ciao, Bari');
        expect(zip.read('missing.txt'), isNull);
      }
    });

    test('rejects what is not a ZIP archive', () {
      expect(
        () => ZipReader(Uint8List.fromList(List.filled(100, 7))),
        throwsFormatException,
      );
    });
  });

  test('csvRows handles quotes, commas and CRLF', () {
    expect(csvRows('a,b\r\n"x, y","say ""hi"""\r\n').toList(), [
      ['a', 'b'],
      ['x, y', 'say "hi"'],
    ]);
  });

  group('import and schedule', () {
    late TransitStore store;

    setUp(() {
      final out = Directory('${dir.path}/transit/amtab');
      final result = GtfsImport.build(ZipReader(zipOf(tinyFeed(today))), out);
      expect(result.stops, 2);
      expect(result.validUntil, DateTime(2026, 11, 7));
      store = TransitStore(dir, http.Client(), url: Uri.parse('https://x'));
    });

    test('keeps stops with their lines', () async {
      final stops = await store.loadStops();
      expect(stops.map((s) => s.name), ['Piccinni, Teatro', 'Stazione']);
      expect(await store.loadStopRoutes(), [
        [0],
        <int>[],
      ]);
      final routes = await store.loadRoutes();
      expect(routes.single.name, '02/');
      expect(routes.single.color, 0x5F9EA0);
    });

    test('lists the next departures, also past midnight', () async {
      final raw = await store.loadDepartures(0);
      final routes = await store.loadRoutes();
      final services = await store.loadServices();
      final departures = TransitSchedule.departures(
        raw,
        services: services,
        routes: routes,
        now: DateTime(2026, 11, 4, 8, 3),
      );
      expect(departures.first.time, DateTime(2026, 11, 4, 8, 10));
      expect(departures.first.route, '02/');
      expect(departures.first.headsign, 'Stazione');
      expect(departures, hasLength(3));

      // 01:05 is served by yesterday's 25:10 trip as well as today's 01:10.
      final night = TransitSchedule.departures(
        raw,
        services: services,
        routes: routes,
        now: DateTime(2026, 11, 4, 1, 5),
        window: const Duration(minutes: 6),
      );
      expect(night.map((d) => d.time), [
        DateTime(2026, 11, 4, 1, 10),
        DateTime(2026, 11, 4, 1, 10),
      ]);
    });

    test('nothing runs outside the calendar', () async {
      final departures = TransitSchedule.departures(
        await store.loadDepartures(0),
        services: await store.loadServices(),
        routes: await store.loadRoutes(),
        now: DateTime(2026, 12, 25, 10),
      );
      expect(departures, isEmpty);
    });

    test('puts buses halfway between stops halfway along the line', () async {
      final route = (await store.loadRoute(0))!;
      final vehicles = TransitSchedule.vehicles(
        route,
        services: await store.loadServices(),
        now: DateTime(2026, 11, 4, 8, 12, 30),
      );
      // The 8:10 trip, 2.5 of its 5 minutes from A to B.
      expect(vehicles, hasLength(1));
      final bus = vehicles.single;
      expect(bus.point.latitude, closeTo(41.1245, 0.0002));
      expect(bus.bearing, closeTo(0, 1));
      expect(bus.headsign, 'Stazione');
    });
  });

  test('ServiceDays applies exceptions over the weekly calendar', () {
    const days = ServiceDays(
      start: 20261101,
      end: 20261130,
      weekdays: 0x1F, // Monday to Friday.
      added: {20261108},
      removed: {20261104},
    );
    expect(days.runsOn(DateTime(2026, 11, 3)), isTrue);
    expect(days.runsOn(DateTime(2026, 11, 4)), isFalse);
    expect(days.runsOn(DateTime(2026, 11, 7)), isFalse);
    expect(days.runsOn(DateTime(2026, 11, 8)), isTrue);
  });

  test('pointAlong walks the line and reports its direction', () {
    const a = GeoPoint(latitude: 41.12, longitude: 16.87);
    const b = GeoPoint(latitude: 41.12, longitude: 16.88);
    final (point, bearing) = TransitSchedule.pointAlong(const [a, b], 420)!;
    expect(point.distanceTo(a), closeTo(420, 2));
    expect(bearing, closeTo(90, 1));
  });
}
