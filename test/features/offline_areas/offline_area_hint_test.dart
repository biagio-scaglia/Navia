import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/network/json_http_client.dart';
import 'package:navia/features/offline_areas/offline_area_hint.dart';
import 'package:navia/features/offline_maps/data/map_data_client.dart';
import 'package:navia/features/offline_maps/domain/map_region.dart';
import 'package:navia/features/offline_maps/presentation/offline_maps_controller.dart';
import 'package:navia/features/places/data/place_data_client.dart';
import 'package:navia/features/places/domain/place_region.dart';
import 'package:navia/features/places/presentation/offline_places_controller.dart';
import 'package:navia/shared/models/geo_bounds.dart';
import 'package:navia/shared/models/geo_point.dart';
import 'package:navia/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _south = GeoBounds.tryCreate(
  south: 37.9,
  west: 13,
  north: 42.9,
  east: 18.5,
)!;
const _bari = GeoPoint(latitude: 41.12, longitude: 16.87);
const _milano = GeoPoint(latitude: 45.46, longitude: 9.19);

final _places = InstalledRegion(
  region: PlaceRegion(
    id: 'sud',
    name: 'Sud',
    detail: '',
    file: 'places-sud.jsonl.gz',
    bytes: 1,
    sha256: '0' * 64,
    count: 1,
    bounds: _south,
  ),
  installedAt: DateTime.utc(2026),
  bytesOnDisk: 1,
);

final _map = InstalledMapRegion(
  region: MapRegion(
    id: 'sud',
    name: 'Sud',
    detail: '',
    file: 'map-sud.pmtiles',
    bytes: 1,
    sha256: '0' * 64,
    maxZoom: 14,
    bounds: _south,
  ),
  installedAt: DateTime.utc(2026),
  tilesPath: '/tmp/map-sud.pmtiles',
);

Future<ProviderContainer> _container({
  List<InstalledMapRegion> maps = const [],
  List<InstalledRegion> places = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final mock = MockClient((_) async => http.Response('', 404));
  final json = JsonHttpClient(mock, userAgent: 'Navia/test');
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      mapDataClientProvider.overrideWithValue(
        MapDataClient(mock, json, baseUrl: 'https://x', userAgent: 'Navia'),
      ),
      placeDataClientProvider.overrideWithValue(
        PlaceDataClient(mock, json, baseUrl: 'https://x', userAgent: 'Navia'),
      ),
      installedMapRegionsProvider.overrideWithValue(maps),
      installedRegionsProvider.overrideWithValue(places),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('points out the missing map where only places are stored', () async {
    final container = await _container(places: [_places]);
    container.read(offlineAreaHintProvider.notifier).centerChanged(_bari);

    final hint = container.read(offlineAreaHintProvider);
    expect(hint?.gap, OfflineAreaGap.map);
    expect(hint?.regionName, 'Sud');
  });

  test('points out the missing places where only the map is stored', () async {
    final container = await _container(maps: [_map]);
    container.read(offlineAreaHintProvider.notifier).centerChanged(_bari);

    expect(container.read(offlineAreaHintProvider)?.gap, OfflineAreaGap.places);
  });

  test('says nothing with both halves or outside the zone', () async {
    final both = await _container(maps: [_map], places: [_places]);
    both.read(offlineAreaHintProvider.notifier).centerChanged(_bari);
    expect(both.read(offlineAreaHintProvider), isNull);

    final elsewhere = await _container(places: [_places]);
    elsewhere.read(offlineAreaHintProvider.notifier).centerChanged(_milano);
    expect(elsewhere.read(offlineAreaHintProvider), isNull);
  });

  test('a dismissed hint stays hidden', () async {
    final container = await _container(places: [_places]);
    final controller = container.read(offlineAreaHintProvider.notifier)
      ..centerChanged(_bari);
    await controller.dismiss();
    expect(container.read(offlineAreaHintProvider), isNull);

    controller
      ..centerChanged(_milano)
      ..centerChanged(_bari);
    expect(container.read(offlineAreaHintProvider), isNull);
  });
}
