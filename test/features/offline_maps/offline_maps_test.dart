import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/app/config/app_config.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/map/domain/map_style_source.dart';
import 'package:navia/features/offline_maps/data/map_data_client.dart';
import 'package:navia/features/offline_maps/data/offline_map_style.dart';
import 'package:navia/features/offline_maps/data/offline_maps_store.dart';
import 'package:navia/features/offline_maps/domain/map_region.dart';
import 'package:navia/features/offline_maps/presentation/offline_maps_controller.dart';
import 'package:navia/shared/models/geo_bounds.dart';
import 'package:navia/shared/models/geo_point.dart';

/// Stands in for a PMTiles archive: only its bytes matter here.
final _archive = utf8.encode('PMTiles archive of the south');

MapRegion _region(
  List<int> bytes, {
  String id = 'sud',
  String name = 'Sud',
  GeoBounds? bounds,
}) => MapRegion(
  id: id,
  name: name,
  detail: 'Puglia',
  file: 'map-$id.pmtiles',
  bytes: bytes.length,
  sha256: sha256.convert(bytes).toString(),
  maxZoom: 14,
  bounds:
      bounds ?? GeoBounds.tryCreate(south: 37, west: 13, north: 43, east: 19)!,
);

InstalledMapRegion _installed(MapRegion region) => InstalledMapRegion(
  region: region,
  installedAt: DateTime.utc(2026, 11),
  tilesPath: '/data/maps/${region.id}/map.pmtiles',
);

const _bari = GeoPoint(latitude: 41.1171, longitude: 16.8719);
const _milan = GeoPoint(latitude: 45.4642, longitude: 9.19);

/// A small style in the shape of the OpenFreeMap ones.
Map<String, Object?> _template() => {
  'version': 8,
  'glyphs': 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
  'sprite': 'https://tiles.openfreemap.org/sprites/ofm_f384/ofm',
  'sources': {
    'ne2_shaded': {
      'type': 'raster',
      'tiles': ['https://tiles.openfreemap.org/natural_earth/{z}/{x}/{y}.png'],
    },
    'openmaptiles': {
      'type': 'vector',
      'url': 'https://tiles.openfreemap.org/planet',
    },
  },
  'layers': [
    {'id': 'background', 'type': 'background'},
    {'id': 'natural_earth', 'type': 'raster', 'source': 'ne2_shaded'},
    {
      'id': 'water',
      'type': 'fill',
      'source': 'openmaptiles',
      'source-layer': 'water',
    },
    {
      'id': 'poi_r1',
      'type': 'symbol',
      'source': 'openmaptiles',
      'source-layer': 'poi',
      'layout': {
        'text-font': ['Noto Sans Regular'],
      },
    },
  ],
};

MapDataClient _client(MockClientHandler handler) {
  final mock = MockClient(handler);
  return MapDataClient(
    mock,
    JsonHttpClient(mock, userAgent: 'Navia/test'),
    baseUrl: 'https://data.example/map-data',
    userAgent: 'Navia/test',
  );
}

Directory _tempDir() {
  final directory = Directory.systemTemp.createTempSync('navia_maps_');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

void main() {
  group('catalog', () {
    test('parses valid regions and skips unusable ones', () {
      final regions = MapDataClient.parseCatalog({
        'version': 1,
        'regions': [
          _region(_archive).toJson(),
          {..._region(_archive).toJson(), 'file': 'map-sud.zip'},
          {..._region(_archive).toJson(), 'sha256': 'abc'},
          {..._region(_archive).toJson(), 'maxzoom': 30},
          {
            ..._region(_archive).toJson(),
            'bbox': [1, 2, 3],
          },
        ],
      });
      expect(regions, [_region(_archive)]);
      expect(regions.single.maxZoom, 14);
    });

    test('rejects an unknown catalog version', () {
      expect(
        () => MapDataClient.parseCatalog({'version': 2, 'regions': <Object>[]}),
        throwsA(isA<ServiceException>()),
      );
    });
  });

  group('store', () {
    test('installs, lists, replaces and deletes a region', () async {
      final store = OfflineMapsStore(_tempDir());
      final first = _region(_archive);
      final download = File('${store.downloads.path}/sud.pmtiles')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_archive);

      final installed = await store.install(first, download);
      expect(download.existsSync(), isFalse);
      expect(File(installed.tilesPath).readAsBytesSync(), _archive);
      expect(store.installed(), [installed]);

      // An update gets a new path, so the map reloads the tiles.
      final newer = utf8.encode('PMTiles archive, next month');
      final update = _region(newer);
      final replacement = File('${store.downloads.path}/sud.pmtiles')
        ..writeAsBytesSync(newer);
      final updated = await store.install(update, replacement);
      expect(updated.tilesPath, isNot(installed.tilesPath));
      expect(File(installed.tilesPath).existsSync(), isFalse);
      expect(store.installed().single.region.sha256, update.sha256);

      await store.delete('sud');
      expect(store.installed(), isEmpty);
    });

    test('skips a region whose archive is missing', () async {
      final store = OfflineMapsStore(_tempDir());
      final download = File('${store.downloads.path}/sud.pmtiles')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_archive);
      final installed = await store.install(_region(_archive), download);
      File(installed.tilesPath).deleteSync();
      expect(store.installed(), isEmpty);
    });
  });

  group('offline style', () {
    Map<String, dynamic> build(List<InstalledMapRegion> regions) =>
        jsonDecode(
              OfflineMapStyle.build(
                _template(),
                sourceId: 'openmaptiles',
                regions: regions,
              ),
            )
            as Map<String, dynamic>;

    test('reads one region from its archive and the bundled resources', () {
      final style = build([_installed(_region(_archive))]);
      expect(style['sources'], {
        'openmaptiles': {
          'type': 'vector',
          'url': 'pmtiles://file:///data/maps/sud/map.pmtiles',
        },
      });
      final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
      expect(layers.map((l) => l['id']), ['background', 'water', 'poi_r1']);
      expect((layers.last['layout'] as Map)['text-font'], [
        'noto-sans-regular',
      ]);
      expect(
        style['glyphs'],
        'asset://flutter_assets/assets/map_offline/fonts/{fontstack}/'
        '{range}.pbf',
      );
      expect(
        style['sprite'],
        'asset://flutter_assets/assets/map_offline/sprites/ofm',
      );
      expect(jsonEncode(style), isNot(contains('openfreemap')));
    });

    test('repeats each layer for every region, in drawing order', () {
      final style = build([
        _installed(_region(_archive)),
        _installed(_region(_archive, id: 'centro', name: 'Centro')),
      ]);
      expect((style['sources'] as Map).keys, [
        'openmaptiles',
        'openmaptiles-centro',
      ]);
      final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
      expect(layers.map((l) => l['id']), [
        'background',
        'water',
        'water-centro',
        'poi_r1',
        'poi_r1-centro',
      ]);
      expect(layers[2]['source'], 'openmaptiles-centro');
      expect((layers[4]['layout'] as Map)['text-font'], ['noto-sans-regular']);
    });

    test('the template is not modified', () {
      final template = _template();
      OfflineMapStyle.build(
        template,
        sourceId: 'openmaptiles',
        regions: [_installed(_region(_archive))],
      );
      expect(template, _template());
    });

    test('every style of the map provider has a bundled copy', () {
      const source = AppConfig.mapStyleSource;
      expect(source.offlineSourceId, source.buildingsSourceId);
      for (final style in MapStyleId.values) {
        final asset = source.offlineStyles[style];
        expect(asset, isNotNull, reason: '$style');
        final json = jsonDecode(File(asset!).readAsStringSync()) as Map;
        expect((json['sources'] as Map).keys, contains(source.offlineSourceId));
      }
    });

    test('the bundled resources cover the fonts of every style', () {
      const source = AppConfig.mapStyleSource;
      for (final asset in source.offlineStyles.values) {
        final json = jsonDecode(File(asset).readAsStringSync()) as Map;
        for (final layer
            in (json['layers'] as List).cast<Map<String, dynamic>>()) {
          final fonts = (layer['layout'] as Map?)?['text-font'];
          if (fonts is! List) continue;
          for (final font in fonts.cast<String>()) {
            final folder = OfflineMapStyle.fontFolder(font);
            expect(
              File('assets/map_offline/fonts/$folder/0-255.pbf').existsSync(),
              isTrue,
              reason: '$font in $asset',
            );
          }
        }
      }
      for (final file in ['ofm.json', 'ofm.png', 'ofm@2x.json', 'ofm@2x.png']) {
        expect(File('assets/map_offline/sprites/$file').existsSync(), isTrue);
      }
    });
  });

  group('coverage', () {
    ProviderContainer container(List<InstalledMapRegion> installed) {
      final container = ProviderContainer(
        overrides: [
          installedMapRegionsProvider.overrideWithValue(installed),
          offlineStyleTemplateProvider.overrideWith((ref, _) => _template()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('draws the downloaded maps only inside them', () async {
      final sud = _installed(_region(_archive));
      final c = container([sud]);
      c.listen(offlineMapStyleProvider(MapStyleId.standard), (_, _) {});
      await c.read(offlineStyleTemplateProvider('any').future);

      // The initial camera is in Bari, inside the south.
      expect(c.read(offlineMapCoverageProvider), [sud]);
      expect(
        c.read(offlineMapStyleProvider(MapStyleId.standard)),
        contains('pmtiles://file:///data/maps/sud/map.pmtiles'),
      );

      c.read(offlineMapCoverageProvider.notifier).centerChanged(_milan);
      expect(c.read(offlineMapCoverageProvider), isEmpty);
      expect(c.read(offlineMapStyleProvider(MapStyleId.standard)), isNull);

      c.read(offlineMapCoverageProvider.notifier).centerChanged(_bari);
      expect(c.read(offlineMapStyleProvider(MapStyleId.dark)), isNotNull);
    });

    test('without downloaded maps the online style is used', () {
      final c = container(const []);
      expect(c.read(offlineMapStyleProvider(MapStyleId.standard)), isNull);
    });
  });

  test('the controller downloads, installs and deletes a region', () async {
    final region = _region(_archive);
    var dataRequests = 0;
    final container = ProviderContainer(
      overrides: [
        mapsDataDirectoryProvider.overrideWithValue(_tempDir()),
        mapDataClientProvider.overrideWithValue(
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
            dataRequests++;
            expect(request.url.path, '/map-data/map-sud.pmtiles');
            return http.Response.bytes(_archive, 200);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(offlineMapsProvider.notifier);

    await controller.loadCatalog();
    expect(container.read(offlineMapsProvider).catalog, [region]);

    await controller.download(region);
    var state = container.read(offlineMapsProvider);
    expect(dataRequests, 1);
    expect(state.installed.single.region, region);
    expect(state.progress, isEmpty);
    expect(container.read(offlineMapCoverageProvider), state.installed);

    await controller.delete('sud');
    state = container.read(offlineMapsProvider);
    expect(state.installed, isEmpty);
    expect(container.read(offlineMapCoverageProvider), isEmpty);
  });

  test('a corrupted download is reported and not installed', () async {
    final region = _region(_archive);
    final container = ProviderContainer(
      overrides: [
        mapsDataDirectoryProvider.overrideWithValue(_tempDir()),
        mapDataClientProvider.overrideWithValue(
          _client((_) async => http.Response.bytes(utf8.encode('x'), 200)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(offlineMapsProvider.notifier).download(region);
    final state = container.read(offlineMapsProvider);
    expect(state.installed, isEmpty);
    expect(state.failures['sud'], ServiceFailure.malformedResponse);
  });
}
