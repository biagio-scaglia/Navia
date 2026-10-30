import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/favorites/data/favorites_repository.dart';
import 'package:navia/features/favorites/presentation/favorites_controller.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/shared/models/geo_point.dart';
import 'package:navia/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _home = GeoPoint(latitude: 41.1171, longitude: 16.8719);
const _work = GeoPoint(latitude: 41.1253, longitude: 16.8667);

Future<ProviderContainer> _container([
  Map<String, Object> stored = const {},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Reads favorites back from storage through a fresh container, like a new
/// app session would.
Future<List<String>> _storedNames(ProviderContainer container) async {
  final preferences = container.read(sharedPreferencesProvider);
  final next = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(next.dispose);
  return next.read(favoritesProvider).map((f) => f.name).toList();
}

void main() {
  test('starts empty', () async {
    final container = await _container();
    expect(container.read(favoritesProvider), isEmpty);
  });

  test('saves favorites newest first and persists them', () async {
    final container = await _container();
    final controller = container.read(favoritesProvider.notifier);

    expect(await controller.add('  Casa  ', _home), FavoriteAddResult.added);
    expect(await controller.add('Lavoro', _work), FavoriteAddResult.added);

    expect(container.read(favoritesProvider).map((f) => f.name), [
      'Lavoro',
      'Casa',
    ]);
    expect(await _storedNames(container), ['Lavoro', 'Casa']);
  });

  test('rejects duplicates within a few meters', () async {
    final container = await _container();
    final controller = container.read(favoritesProvider.notifier);
    await controller.add('Casa', _home);

    // About 5 m north of the first point.
    const nearby = GeoPoint(latitude: 41.11714, longitude: 16.8719);
    expect(
      await controller.add('Casa di nuovo', nearby),
      FavoriteAddResult.duplicate,
    );
    expect(controller.findExisting(nearby)?.name, 'Casa');
    expect(container.read(favoritesProvider), hasLength(1));
  });

  test('rejects blank names', () async {
    final container = await _container();
    final result = await container
        .read(favoritesProvider.notifier)
        .add('   ', _home);
    expect(result, FavoriteAddResult.invalidName);
  });

  test('renames, removes and restores', () async {
    final container = await _container();
    final controller = container.read(favoritesProvider.notifier);
    await controller.add('Casa', _home);
    await controller.add('Lavoro', _work);
    final id = container.read(favoritesProvider).last.id;

    expect(await controller.rename(id, 'Casa al mare'), isTrue);
    expect(container.read(favoritesProvider).last.name, 'Casa al mare');

    final removed = await controller.remove(id);
    expect(container.read(favoritesProvider).map((f) => f.name), ['Lavoro']);
    expect(await _storedNames(container), ['Lavoro']);

    await controller.restore(removed!);
    expect(container.read(favoritesProvider).map((f) => f.name), [
      'Lavoro',
      'Casa al mare',
    ]);
  });

  test('skips corrupted stored entries', () async {
    final container = await _container({
      FavoritesRepository.storageKey: jsonEncode([
        {
          'id': '1',
          'name': 'Valido',
          'lat': 41.1,
          'lng': 16.8,
          'createdAt': '2026-10-30T10:00:00Z',
        },
        {'id': '2', 'name': 'Senza coordinate'},
        {
          'id': '3',
          'name': 'Fuori scala',
          'lat': 200,
          'lng': 16.8,
          'createdAt': '2026-10-30T10:00:00Z',
        },
        'garbage',
      ]),
    });

    expect(container.read(favoritesProvider).map((f) => f.name), ['Valido']);
  });

  test('survives unreadable storage', () async {
    final container = await _container({
      FavoritesRepository.storageKey: '{not json',
    });
    expect(container.read(favoritesProvider), isEmpty);
  });

  test('keeps the source metadata of a saved place across sessions', () async {
    final container = await _container();
    await container
        .read(favoritesProvider.notifier)
        .add(
          'Farmacia',
          _home,
          osmRef: const OsmRef(OsmElementType.node, 101),
          category: 'Farmacia',
          address: 'Via Sparano da Bari, 5',
        );

    final preferences = container.read(sharedPreferencesProvider);
    final next = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(next.dispose);
    final favorite = next.read(favoritesProvider).single;
    expect(favorite.osmRef, const OsmRef(OsmElementType.node, 101));
    expect(favorite.category, 'Farmacia');
    expect(favorite.address, 'Via Sparano da Bari, 5');
  });

  test('reads favorites saved before metadata existed', () async {
    final container = await _container({
      FavoritesRepository.storageKey: jsonEncode([
        {
          'id': '1',
          'name': 'Casa',
          'lat': 41.1171,
          'lng': 16.8719,
          'createdAt': '2026-10-01T10:00:00.000Z',
        },
      ]),
    });
    final favorite = container.read(favoritesProvider).single;
    expect(favorite.name, 'Casa');
    expect(favorite.osmRef, isNull);
    expect(favorite.category, isNull);
  });

  test('treats the same OpenStreetMap object as a duplicate', () async {
    final container = await _container();
    final controller = container.read(favoritesProvider.notifier);
    const ref = OsmRef(OsmElementType.way, 9);
    await controller.add('Parco', _home, osmRef: ref);

    // Same object, saved again from a different point of its area.
    expect(
      await controller.add('Parco 2', _work, osmRef: ref),
      FavoriteAddResult.duplicate,
    );
    expect(controller.findExisting(_work, osmRef: ref)?.name, 'Parco');
    expect(controller.findExisting(_work), isNull);
  });
}
