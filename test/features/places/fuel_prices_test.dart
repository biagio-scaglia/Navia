import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/features/places/data/fuel_prices_store.dart';
import 'package:navia/features/places/domain/fuel.dart';
import 'package:navia/features/places/domain/places_repository.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/features/places/domain/poi_category.dart';
import 'package:navia/features/places/presentation/fuel_prices_controller.dart';
import 'package:navia/shared/models/geo_bounds.dart';
import 'package:navia/shared/models/geo_point.dart';

const _entry = [
  59183,
  41.1200,
  16.8700,
  'Agip Eni',
  'Bari Centro',
  'Via Sparano 1',
  'BARI',
  [
    ['Benzina', 1.99, true, '2026-10-28T12:58'],
    ['Gasolio', 2.4, false, '2026-10-28T15:07'],
    ['Broken'],
  ],
];

List<int> _dataset() => gzip.encode(
  utf8.encode(
    jsonEncode({
      'version': 1,
      'extracted': '2026-10-30',
      'stations': [_entry],
    }),
  ),
);

Poi _poi(int id, GeoPoint point) =>
    Poi(ref: OsmRef(OsmElementType.node, id), point: point);

Directory _tempDir() {
  final directory = Directory.systemTemp.createTempSync('navia_fuel_');
  addTearDown(() => directory.deleteSync(recursive: true));
  return directory;
}

class _Places implements PlacesRepository {
  @override
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds) async => [
    _poi(1, const GeoPoint(latitude: 41.12003, longitude: 16.87004)),
  ];
}

void main() {
  test('parses a registry station and skips malformed prices', () {
    final station = FuelStation.tryParse(_entry)!;
    expect(station.brand, 'Agip Eni');
    expect(station.prices, hasLength(2));
    expect(station.prices.first.selfService, isTrue);
    expect(station.prices.last.price, 2.4);
    expect(FuelStation.tryParse(['x']), isNull);
  });

  test('matches registry stations within 80 m only', () {
    final station = FuelStation.tryParse(_entry)!;
    final annotated = FuelPriceMatcher.annotate(
      [
        _poi(1, const GeoPoint(latitude: 41.12004, longitude: 16.87003)),
        _poi(2, const GeoPoint(latitude: 41.1300, longitude: 16.8700)),
      ],
      [station],
    );
    expect(annotated.first.fuel?.id, 59183);
    expect(annotated.last.fuel, isNull);
  });

  test('downloads, validates, loads and deletes the dataset', () async {
    final store = FuelPricesStore(
      _tempDir(),
      MockClient((_) async => http.Response.bytes(_dataset(), 200)),
      url: Uri.parse('https://data.example/fuel-prices.json.gz'),
    );
    expect(store.info(), isNull);

    final info = await store.download(userAgent: 'Navia/test');
    expect(info.extracted, DateTime(2026, 10, 30));
    expect(store.info()?.bytes, info.bytes);
    expect((await store.load()).single.name, 'Bari Centro');

    await store.delete();
    expect(store.info(), isNull);
  });

  test('rejects a file that is not a fuel dataset', () async {
    final store = FuelPricesStore(
      _tempDir(),
      MockClient(
        (_) async => http.Response.bytes(gzip.encode(utf8.encode('{}')), 200),
      ),
      url: Uri.parse('https://data.example/fuel-prices.json.gz'),
    );
    await expectLater(
      store.download(userAgent: 'Navia/test'),
      throwsA(
        isA<ServiceException>().having(
          (e) => e.failure,
          'failure',
          ServiceFailure.malformedResponse,
        ),
      ),
    );
    expect(store.info(), isNull);
  });

  test('only fuel discovery gets prices attached', () async {
    final station = FuelStation.tryParse(_entry)!;
    final repository = FuelPricedPlacesRepository(
      _Places(),
      () async => [station],
    );
    final bounds = GeoBounds.tryCreate(
      south: 41.1,
      west: 16.8,
      north: 41.2,
      east: 16.9,
    )!;
    expect(
      (await repository.fetch(PoiCategory.fuel, bounds)).single.fuel?.id,
      59183,
    );
    expect(
      (await repository.fetch(PoiCategory.cafes, bounds)).single.fuel,
      isNull,
    );
  });
}
