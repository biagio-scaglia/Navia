import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/places/data/local_first_places_repository.dart';
import 'package:navia/features/places/data/offline_places_store.dart';
import 'package:navia/features/places/data/place_data_client.dart';
import 'package:navia/features/places/domain/place_region.dart';
import 'package:navia/features/places/domain/places_repository.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/features/places/domain/poi_category.dart';
import 'package:navia/features/places/presentation/offline_places_controller.dart';
import 'package:navia/shared/models/geo_bounds.dart';

/// A small dataset in the published format: places around Bari.
List<int> _dataset() {
  final lines = [
    {
      'id': 'node/1',
      'lat': 41.1201,
      'lon': 16.8702,
      'tags': {'amenity': 'pharmacy', 'name': 'Farmacia Centrale'},
    },
    {
      'id': 'way/2',
      'lat': 41.1230,
      'lon': 16.8710,
      'tags': {'amenity': 'restaurant', 'name': 'Trattoria'},
    },
    {
      'id': 'node/3',
      'lat': 41.3000,
      'lon': 16.2800,
      'tags': {'amenity': 'pharmacy', 'name': 'Farmacia di Barletta'},
    },
  ].map(jsonEncode).join('\n');
  return gzip.encode(utf8.encode('$lines\n'));
}

PlaceRegion _region(List<int> bytes) => PlaceRegion(
  id: 'sud',
  name: 'Sud',
  detail: 'Puglia',
  file: 'places-sud.jsonl.gz',
  bytes: bytes.length,
  sha256: sha256.convert(bytes).toString(),
  count: 3,
  bounds: GeoBounds.tryCreate(south: 40, west: 15, north: 42, east: 18)!,
);

final _bari = GeoBounds.tryCreate(
  south: 41.11,
  west: 16.86,
  north: 41.13,
  east: 16.88,
)!;

Matcher _failsWith(ServiceFailure failure) => throwsA(
  isA<ServiceException>().having((e) => e.failure, 'failure', failure),
);

PlaceDataClient _client(MockClientHandler handler) {
  final mock = MockClient(handler);
  return PlaceDataClient(
    mock,
    JsonHttpClient(mock, userAgent: 'Navia/test'),
    baseUrl: 'https://data.example/places-data',
    userAgent: 'Navia/test',
  );
}

Directory _tempDir() {
  final directory = Directory.systemTemp.createTempSync('navia_places_');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

void main() {
  group('catalog', () {
    test('parses valid regions and skips unusable ones', () {
      final bytes = _dataset();
      final regions = PlaceDataClient.parseCatalog({
        'version': 1,
        'regions': [
          _region(bytes).toJson(),
          {'id': '../escape', 'name': 'X'},
          {..._region(bytes).toJson(), 'file': '../../etc/passwd'},
          {..._region(bytes).toJson(), 'sha256': 'abc'},
        ],
      });
      expect(regions.single.id, 'sud');
      expect(regions.single.bounds.north, 42);
    });

    test('rejects unknown catalog versions', () {
      expect(
        () =>
            PlaceDataClient.parseCatalog({'version': 2, 'regions': <Object>[]}),
        _failsWith(ServiceFailure.malformedResponse),
      );
    });
  });

  group('download', () {
    test('saves the file and reports progress', () async {
      final bytes = _dataset();
      final target = File('${_tempDir().path}/sud.jsonl.gz');
      final progress = <int>[];
      final client = _client((request) async {
        expect(request.url.path, '/places-data/places-sud.jsonl.gz');
        return http.Response.bytes(bytes, 200);
      });

      await client.download(
        _region(bytes),
        target,
        onProgress: (received, total) => progress.add(received),
      );

      expect(target.readAsBytesSync(), bytes);
      expect(progress.last, bytes.length);
    });

    test('deletes a file whose checksum does not match', () async {
      final bytes = _dataset();
      final target = File('${_tempDir().path}/sud.jsonl.gz');
      final tampered = [...bytes]..[10] ^= 0xff;
      final client = _client((_) async => http.Response.bytes(tampered, 200));

      await expectLater(
        client.download(_region(bytes), target),
        _failsWith(ServiceFailure.malformedResponse),
      );
      expect(target.existsSync(), isFalse);
    });

    test('stops when cancelled', () async {
      final bytes = _dataset();
      final target = File('${_tempDir().path}/sud.jsonl.gz');
      final client = _client((_) async => http.Response.bytes(bytes, 200));

      await expectLater(
        client.download(_region(bytes), target, isCancelled: () => true),
        throwsA(isA<DownloadCancelled>()),
      );
      expect(target.existsSync(), isFalse);
    });

    test('maps server errors', () async {
      final bytes = _dataset();
      final target = File('${_tempDir().path}/sud.jsonl.gz');
      final client = _client((_) async => http.Response('', 503));
      await expectLater(
        client.download(_region(bytes), target),
        _failsWith(ServiceFailure.unavailable),
      );
    });
  });

  group('OfflinePlacesStore', () {
    Future<(OfflinePlacesStore, InstalledRegion)> install() async {
      final store = OfflinePlacesStore(_tempDir());
      final bytes = _dataset();
      final file = File('${store.downloads.path}/sud.jsonl.gz')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      final installed = await store.install(_region(bytes), file);
      expect(file.existsSync(), isFalse);
      return (store, installed);
    }

    test('installs a region and lists it', () async {
      final (store, installed) = await install();
      expect(store.installed().single, installed);
      expect(installed.bytesOnDisk, greaterThan(0));
    });

    test('answers queries by category and area', () async {
      final (store, installed) = await install();

      final pharmacies = await store.query(PoiCategory.pharmacies, _bari, [
        installed,
      ], limit: PlacesRepository.maxResults);
      expect(pharmacies.single.name, 'Farmacia Centrale');
      expect(pharmacies.single.ref, const OsmRef(OsmElementType.node, 1));
      expect(pharmacies.single.category, 'Farmacia');

      final restaurants = await store.query(PoiCategory.restaurants, _bari, [
        installed,
      ], limit: 10);
      expect(restaurants.single.ref.key, 'way/2');
    });

    test('deletes a region', () async {
      final (store, _) = await install();
      await store.delete('sud');
      expect(store.installed(), isEmpty);
    });
  });

  group('LocalFirstPlacesRepository', () {
    test('uses downloaded data where it covers the view', () async {
      final store = OfflinePlacesStore(_tempDir());
      final bytes = _dataset();
      final file = File('${store.downloads.path}/sud.jsonl.gz')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      final installed = await store.install(_region(bytes), file);
      final online = _CountingPlaces();
      final repository = LocalFirstPlacesRepository(
        store: store,
        installed: [installed],
        online: online,
      );

      final local = await repository.fetch(PoiCategory.pharmacies, _bari);
      expect(local.single.name, 'Farmacia Centrale');
      expect(online.calls, 0);

      final milan = GeoBounds.tryCreate(
        south: 45.45,
        west: 9.17,
        north: 45.47,
        east: 9.20,
      )!;
      await repository.fetch(PoiCategory.pharmacies, milan);
      expect(online.calls, 1);
    });

    test('without an online service, asks for a download', () {
      final repository = LocalFirstPlacesRepository(
        store: OfflinePlacesStore(_tempDir()),
        installed: const [],
      );
      expect(
        () => repository.fetch(PoiCategory.pharmacies, _bari),
        _failsWith(ServiceFailure.notConfigured),
      );
    });
  });

  test('the controller downloads, installs and deletes a region', () async {
    final bytes = _dataset();
    final region = _region(bytes);
    final container = ProviderContainer(
      overrides: [
        placesDataDirectoryProvider.overrideWithValue(_tempDir()),
        placeDataClientProvider.overrideWithValue(
          _client((request) async {
            if (request.url.path.endsWith('manifest.json')) {
              return http.Response(
                jsonEncode({
                  'version': 1,
                  'regions': [region.toJson()],
                }),
                200,
              );
            }
            return http.Response.bytes(bytes, 200);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(offlinePlacesProvider.notifier);

    await controller.loadCatalog();
    expect(container.read(offlinePlacesProvider).catalog.single.id, 'sud');

    await controller.download(region);
    var state = container.read(offlinePlacesProvider);
    expect(state.installed.single.region.id, 'sud');
    expect(state.progress, isEmpty);
    expect(container.read(installedRegionsProvider), hasLength(1));

    await controller.delete('sud');
    state = container.read(offlinePlacesProvider);
    expect(state.installed, isEmpty);
  });
}

class _CountingPlaces implements PlacesRepository {
  int calls = 0;

  @override
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds) async {
    calls++;
    return const [];
  }
}
