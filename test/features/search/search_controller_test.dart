import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/features/search/data/photon_geocoding_repository.dart';
import 'package:navia/features/search/domain/geocoding_repository.dart';
import 'package:navia/features/search/domain/place.dart';
import 'package:navia/features/search/presentation/search_controller.dart';
import 'package:navia/shared/models/geo_point.dart';

const _bari = GeoPoint(latitude: 41.1171, longitude: 16.8719);
const _debounce = Duration(milliseconds: 20);

Place _place(String name) => Place(name: name, point: _bari);

/// Geocoder whose responses are completed manually by the test.
class _ControlledGeocoder implements GeocodingRepository {
  final List<String> queries = [];
  final Map<String, Completer<List<Place>>> pending = {};

  @override
  Future<List<Place>> search(String query, {GeoPoint? near}) {
    queries.add(query);
    return (pending[query] = Completer<List<Place>>()).future;
  }

  @override
  Future<Place?> reverse(GeoPoint point) async => null;
}

ProviderContainer _container(GeocodingRepository? repository) {
  final container = ProviderContainer(
    overrides: [
      geocodingRepositoryProvider.overrideWithValue(repository),
      searchDebounceProvider.overrideWithValue(_debounce),
      searchBiasProvider.overrideWithValue(_bari),
    ],
  );
  addTearDown(container.dispose);
  // Keeps the auto-dispose provider alive for the whole test.
  container.listen(searchControllerProvider, (_, _) {});
  return container;
}

Future<void> _pastDebounce() => Future<void>.delayed(_debounce * 3);

void main() {
  test('debounces typing into a single request', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);
    final controller = container.read(searchControllerProvider.notifier);

    controller
      ..updateQuery('Bar')
      ..updateQuery('Bari')
      ..updateQuery('Bari v');
    expect(
      container.read(searchControllerProvider).status,
      SearchStatus.loading,
    );
    await _pastDebounce();

    expect(geocoder.queries, ['Bari v']);
  });

  test('does not search queries shorter than the minimum length', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);

    container.read(searchControllerProvider.notifier).updateQuery('Ba');
    await _pastDebounce();

    expect(geocoder.queries, isEmpty);
    expect(container.read(searchControllerProvider).status, SearchStatus.idle);
  });

  test('ignores responses of outdated queries', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);
    final controller = container.read(searchControllerProvider.notifier);

    controller.updateQuery('Bari');
    await _pastDebounce();
    controller.updateQuery('Bitonto');
    await _pastDebounce();

    geocoder.pending['Bitonto']!.complete([_place('Bitonto')]);
    await Future<void>.delayed(Duration.zero);
    geocoder.pending['Bari']!.complete([_place('Bari')]);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(searchControllerProvider);
    expect(state.query, 'Bitonto');
    expect(state.results.map((p) => p.name), ['Bitonto']);
  });

  test('serves repeated queries from the cache', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);
    final controller = container.read(searchControllerProvider.notifier);

    controller.updateQuery('Bari');
    await _pastDebounce();
    geocoder.pending['Bari']!.complete([_place('Bari')]);
    await Future<void>.delayed(Duration.zero);
    controller
      ..updateQuery('Bar')
      ..updateQuery('bari');

    expect(geocoder.queries, ['Bari']);
    expect(
      container.read(searchControllerProvider).status,
      SearchStatus.results,
    );
  });

  test('reports empty results', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);

    container.read(searchControllerProvider.notifier).updateQuery('zzzz');
    await _pastDebounce();
    geocoder.pending['zzzz']!.complete([]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(searchControllerProvider).status, SearchStatus.empty);
  });

  test('reports service failures and recovers on retry', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);
    final controller = container.read(searchControllerProvider.notifier);

    controller.updateQuery('Bari');
    await _pastDebounce();
    geocoder.pending['Bari']!.completeError(
      const ServiceException(ServiceFailure.noConnection),
    );
    await Future<void>.delayed(Duration.zero);

    var state = container.read(searchControllerProvider);
    expect(state.status, SearchStatus.failed);
    expect(state.failure, ServiceFailure.noConnection);

    final retry = controller.retry();
    geocoder.pending['Bari']!.complete([_place('Bari')]);
    await retry;

    state = container.read(searchControllerProvider);
    expect(state.status, SearchStatus.results);
    expect(geocoder.queries, ['Bari', 'Bari']);
  });

  test('reports a missing geocoder configuration', () async {
    final container = _container(null);

    container.read(searchControllerProvider.notifier).updateQuery('Bari');
    await _pastDebounce();

    expect(
      container.read(searchControllerProvider).failure,
      ServiceFailure.notConfigured,
    );
  });

  test('submit searches immediately, skipping the debounce', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);
    final controller = container.read(searchControllerProvider.notifier);

    controller.updateQuery('Bari');
    final submitted = controller.submit('Bari');
    expect(geocoder.queries, ['Bari']);

    geocoder.pending['Bari']!.complete([_place('Bari')]);
    await submitted;
    // The cancelled debounce must not send a second request.
    await _pastDebounce();

    expect(geocoder.queries, ['Bari']);
    expect(
      container.read(searchControllerProvider).status,
      SearchStatus.results,
    );
  });

  test('submit does not repeat a request already in flight', () async {
    final geocoder = _ControlledGeocoder();
    final container = _container(geocoder);
    final controller = container.read(searchControllerProvider.notifier);

    final first = controller.submit('Bari');
    final second = controller.submit('Bari');
    geocoder.pending['Bari']!.complete([_place('Bari')]);
    await Future.wait([first, second]);

    expect(geocoder.queries, ['Bari']);
  });
}
