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

  const stationsCsv =
      'Estrazione del 2026-10-30\n'
      'idImpianto|Gestore|Bandiera|Tipo Impianto|Nome Impianto|Indirizzo|'
      'Comune|Provincia|Latitudine|Longitudine\n'
      '59183|ENI SPA|Agip Eni|Stradale|Bari Centro|Via  Sparano 1|BARI|BA|'
      '41.12|16.87\n'
      '1|X|Y|Stradale|Fuori|Via|LONDRA|XX|51.5|-0.1\n';
  const pricesCsv =
      'Estrazione del 2026-10-30\n'
      'idImpianto|descCarburante|prezzo|isSelf|dtComu\n'
      '59183|Benzina|1.99|1|28/10/2026 12:58:00\n'
      '59183|Gasolio|2.4|0|28/10/2026 15:07:00\n'
      '59183|Gasolio|99|1|28/10/2026 15:07:00\n'
      '1|Benzina|1.8|1|28/10/2026 10:00:00\n';

  FuelPricesStore store(MockClientHandler handler) => FuelPricesStore(
    _tempDir(),
    MockClient(handler),
    url: Uri.parse('https://data.example/exportCSV/'),
  );

  test('downloads the Ministry files, joins, loads and deletes them', () async {
    final requested = <String>[];
    final fuel = store((request) async {
      requested.add(request.url.path);
      return http.Response(
        request.url.path.endsWith('prezzo_alle_8.csv')
            ? pricesCsv
            : stationsCsv,
        200,
      );
    });
    expect(fuel.info(), isNull);

    final progress = <int>[];
    final info = await fuel.download(
      userAgent: 'Navia/test',
      onProgress: (received, total) => progress.add(received),
    );
    expect(requested, [
      '/exportCSV/anagrafica_impianti_attivi.csv',
      '/exportCSV/prezzo_alle_8.csv',
    ]);
    expect(info.extracted, DateTime(2026, 10, 30));
    expect(progress.last, 2000);

    final station = (await fuel.load()).single;
    expect(station.name, 'Bari Centro');
    expect(station.address, 'Via Sparano 1');
    // The implausible 99 EUR price is dropped.
    expect(station.prices, hasLength(2));
    expect(station.prices.first.reportedAt, DateTime(2026, 10, 28, 12, 58));

    await fuel.delete();
    expect(fuel.info(), isNull);
  });

  test('rejects files that are not the Ministry datasets', () async {
    final fuel = store((_) async => http.Response('<html>errore</html>', 200));
    await expectLater(
      fuel.download(userAgent: 'Navia/test'),
      throwsA(
        isA<ServiceException>().having(
          (e) => e.failure,
          'failure',
          ServiceFailure.malformedResponse,
        ),
      ),
    );
    expect(fuel.info(), isNull);
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
