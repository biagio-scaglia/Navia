import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/features/places/data/overpass_places_repository.dart';
import 'package:navia/features/places/data/places_cache.dart';
import 'package:navia/features/places/domain/places_repository.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/features/places/domain/poi_category.dart';
import 'package:navia/features/places/presentation/place_discovery_controller.dart';
import 'package:navia/shared/models/geo_bounds.dart';
import 'package:navia/shared/models/geo_point.dart';

/// Places source whose answers are completed by the test.
class _ControlledPlaces implements PlacesRepository {
  final requests = <(PoiCategory, GeoBounds)>[];
  final pending = <Completer<List<Poi>>>[];

  @override
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds) {
    requests.add((category, bounds));
    final completer = Completer<List<Poi>>();
    pending.add(completer);
    return completer.future;
  }
}

Poi _poi(int id, {String? name}) => Poi(
  ref: OsmRef(OsmElementType.node, id),
  point: const GeoPoint(latitude: 41.12, longitude: 16.87),
  name: name,
);

GeoBounds _view(double south, double west, [double span = 0.02]) =>
    GeoBounds.tryCreate(
      south: south,
      west: west,
      north: south + span,
      east: west + span,
    )!;

typedef _Setup = ({
  ProviderContainer container,
  _ControlledPlaces places,
  PlaceDiscoveryController controller,
});

_Setup _setup({PlacesCache? cache}) {
  final places = _ControlledPlaces();
  final container = ProviderContainer(
    overrides: [
      placesRepositoryProvider.overrideWithValue(places),
      placesDebounceProvider.overrideWithValue(Duration.zero),
      if (cache != null) placesCacheProvider.overrideWithValue(cache),
    ],
  );
  addTearDown(container.dispose);
  final controller = container.read(placeDiscoveryProvider.notifier);
  return (container: container, places: places, controller: controller);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('stays idle and silent until a category is chosen', () async {
    final (:container, :places, :controller) = _setup();
    controller.viewportChanged(_view(41.11, 16.86), 15);
    await _settle();

    expect(places.requests, isEmpty);
    expect(container.read(placeDiscoveryProvider).status, DiscoveryStatus.idle);
  });

  test('loads the visible area with a snapped margin', () async {
    final (:container, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.111, 16.861), 15)
      ..select(PoiCategory.pharmacies);
    await _settle();

    final (category, area) = places.requests.single;
    expect(category, PoiCategory.pharmacies);
    expect(area.containsBounds(_view(41.111, 16.861)), isTrue);
    expect(area.south, closeTo(41.10, 1e-9));

    places.pending.single.complete([_poi(1, name: 'Farmacia')]);
    await _settle();
    final state = container.read(placeDiscoveryProvider);
    expect(state.status, DiscoveryStatus.ready);
    expect(state.places.single.name, 'Farmacia');
    expect(controller.placeByKey('node/1')?.name, 'Farmacia');
  });

  test('does not query again for small pans inside the loaded area', () async {
    final (container: _, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.11, 16.86), 15)
      ..select(PoiCategory.cafes);
    await _settle();
    places.pending.single.complete([]);
    await _settle();

    controller.viewportChanged(_view(41.112, 16.862), 15.5);
    await _settle();

    expect(places.requests, hasLength(1));
  });

  test('serves a previously loaded area from the cache', () async {
    final (container: _, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.11, 16.86), 15)
      ..select(PoiCategory.cafes);
    await _settle();
    places.pending.single.complete([_poi(1)]);
    await _settle();

    controller
      ..select(PoiCategory.parks)
      ..select(PoiCategory.cafes);
    await _settle();

    // Only the parks request: cafés come from the cache.
    expect(places.requests.map((r) => r.$1), [
      PoiCategory.cafes,
      PoiCategory.parks,
    ]);
  });

  test('sends a request only once while it is in flight', () async {
    final (container: _, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.11, 16.86), 15)
      ..select(PoiCategory.cafes);
    await _settle();
    controller.viewportChanged(_view(41.1101, 16.8601), 15);
    await _settle();

    expect(places.requests, hasLength(1));
  });

  test('ignores answers for a category that is no longer selected', () async {
    final (:container, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.11, 16.86), 15)
      ..select(PoiCategory.cafes);
    await _settle();
    controller.select(PoiCategory.museums);
    await _settle();

    places.pending.first.complete([_poi(1, name: 'Bar')]);
    await _settle();

    final state = container.read(placeDiscoveryProvider);
    expect(state.category, PoiCategory.museums);
    expect(state.status, DiscoveryStatus.loading);
    expect(state.places, isEmpty);
  });

  test('asks to zoom in instead of querying large areas', () async {
    final (:container, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.0, 16.7, 0.3), 11)
      ..select(PoiCategory.restaurants);
    await _settle();

    expect(places.requests, isEmpty);
    expect(
      container.read(placeDiscoveryProvider).status,
      DiscoveryStatus.zoomIn,
    );
  });

  test('reports failures and recovers on retry', () async {
    final (:container, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.11, 16.86), 15)
      ..select(PoiCategory.fuel);
    await _settle();
    places.pending.single.completeError(
      const ServiceException(ServiceFailure.rateLimited),
    );
    await _settle();

    var state = container.read(placeDiscoveryProvider);
    expect(state.status, DiscoveryStatus.failed);
    expect(state.failure, ServiceFailure.rateLimited);

    final retry = controller.retry();
    places.pending.last.complete([_poi(3)]);
    await retry;
    state = container.read(placeDiscoveryProvider);
    expect(state.status, DiscoveryStatus.ready);
  });

  test('clearing the category removes the places', () async {
    final (:container, :places, :controller) = _setup();
    controller
      ..viewportChanged(_view(41.11, 16.86), 15)
      ..toggle(PoiCategory.atms);
    await _settle();
    places.pending.single.complete([_poi(1)]);
    await _settle();

    controller.toggle(PoiCategory.atms);

    final state = container.read(placeDiscoveryProvider);
    expect(state.category, isNull);
    expect(state.places, isEmpty);
  });

  group('PlacesCache', () {
    final area = _view(41.10, 16.85, 0.04);

    test('expires entries after the maximum age', () {
      var now = DateTime(2026, 11, 2, 10);
      final cache = PlacesCache(clock: () => now)
        ..put(PoiCategory.cafes, area, [_poi(1)]);

      expect(cache.get(PoiCategory.cafes, area), hasLength(1));
      expect(cache.covering(PoiCategory.cafes, _view(41.11, 16.86)), isNotNull);
      now = now.add(const Duration(minutes: 16));
      expect(cache.get(PoiCategory.cafes, area), isNull);
      expect(cache.covering(PoiCategory.cafes, _view(41.11, 16.86)), isNull);
    });

    test('drops the least recently used entry beyond capacity', () {
      final cache = PlacesCache(capacity: 2)
        ..put(PoiCategory.cafes, area, [])
        ..put(PoiCategory.parks, area, []);
      cache
        ..get(PoiCategory.cafes, area)
        ..put(PoiCategory.museums, area, []);

      expect(cache.get(PoiCategory.parks, area), isNull);
      expect(cache.get(PoiCategory.cafes, area), isNotNull);
      expect(cache.get(PoiCategory.museums, area), isNotNull);
    });
  });
}
