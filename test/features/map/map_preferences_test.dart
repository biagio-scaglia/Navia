import 'dart:ui' show Brightness;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/app/config/app_config.dart';
import 'package:navia/features/map/data/map_preferences_repository.dart';
import 'package:navia/features/map/domain/map_style_source.dart';
import 'package:navia/features/map/presentation/map_preferences_controller.dart';
import 'package:navia/features/map/presentation/map_providers.dart';
import 'package:navia/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _standardOnly = MapStyleSource(
  name: 'Test',
  styleUrls: {MapStyleId.standard: 'https://example.org/standard'},
  attributions: [],
);

Future<ProviderContainer> _container({
  Map<String, Object> stored = const {},
  MapStyleSource source = AppConfig.openFreeMap,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      mapStyleSourceProvider.overrideWithValue(source),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('map configuration', () {
    test('starts on Bari at zoom 14', () {
      expect(AppConfig.initialCamera.target.latitude, 41.1171);
      expect(AppConfig.initialCamera.target.longitude, 16.8719);
      expect(AppConfig.initialCamera.zoom, 14);
    });

    test('OpenFreeMap offers every appearance over HTTPS', () {
      for (final appearance in MapAppearance.values) {
        expect(AppConfig.openFreeMap.supports(appearance), isTrue);
      }
      for (final url in AppConfig.openFreeMap.styleUrls.values) {
        expect(Uri.parse(url).scheme, 'https');
      }
    });

    test('keeps the OpenStreetMap attribution first', () {
      expect(
        AppConfig.openFreeMap.attributions.first.url,
        'https://www.openstreetmap.org/copyright',
      );
    });
  });

  group('MapAppearance', () {
    test('automatic follows the app brightness', () {
      expect(
        MapAppearance.automatic.resolve(Brightness.light),
        MapStyleId.standard,
      );
      expect(MapAppearance.automatic.resolve(Brightness.dark), MapStyleId.dark);
    });

    test('explicit choices ignore the app brightness', () {
      expect(
        MapAppearance.minimal.resolve(Brightness.dark),
        MapStyleId.minimal,
      );
      expect(MapAppearance.dark.resolve(Brightness.light), MapStyleId.dark);
    });

    test('unknown stored values fall back to automatic', () {
      expect(MapAppearance.fromStorage('satellite'), MapAppearance.automatic);
      expect(MapAppearance.fromStorage(null), MapAppearance.automatic);
    });

    test('missing styles fall back to the standard URL', () {
      expect(
        _standardOnly.urlFor(MapStyleId.dark),
        'https://example.org/standard',
      );
      expect(_standardOnly.supports(MapAppearance.automatic), isFalse);
      expect(_standardOnly.supports(MapAppearance.standard), isTrue);
    });
  });

  group('MapPreferencesController', () {
    test('defaults to automatic appearance without 3D', () async {
      final container = await _container();
      expect(container.read(mapPreferencesProvider), const MapPreferences());
    });

    test('persists appearance and 3D view', () async {
      final container = await _container();
      final controller = container.read(mapPreferencesProvider.notifier);

      await controller.setAppearance(MapAppearance.minimal);
      await controller.setBuildings3d(true);

      final preferences = container.read(sharedPreferencesProvider);
      expect(
        preferences.getString(MapPreferencesRepository.appearanceKey),
        'minimal',
      );
      expect(
        preferences.getBool(MapPreferencesRepository.buildings3dKey),
        isTrue,
      );
    });

    test('restores stored preferences', () async {
      final container = await _container(
        stored: {
          MapPreferencesRepository.appearanceKey: 'dark',
          MapPreferencesRepository.buildings3dKey: true,
        },
      );
      expect(
        container.read(mapPreferencesProvider),
        const MapPreferences(appearance: MapAppearance.dark, buildings3d: true),
      );
    });

    test('ignores appearances the provider does not offer', () async {
      final container = await _container(
        stored: {MapPreferencesRepository.appearanceKey: 'dark'},
        source: _standardOnly,
      );
      expect(
        container.read(mapPreferencesProvider).appearance,
        MapAppearance.standard,
      );

      await container
          .read(mapPreferencesProvider.notifier)
          .setAppearance(MapAppearance.vivid);

      expect(
        container.read(mapPreferencesProvider).appearance,
        MapAppearance.standard,
      );
    });
  });
}
