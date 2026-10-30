import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/location/data/geolocator_location_repository.dart';
import 'package:navia/features/location/domain/location_models.dart';
import 'package:navia/features/location/presentation/location_controller.dart';
import 'package:navia/shared/models/geo_point.dart';

import 'fake_location_repository.dart';

final _fix = UserPosition(
  point: const GeoPoint(latitude: 41.1253, longitude: 16.8667),
  timestamp: DateTime.utc(2026),
  accuracyMeters: 8,
);

ProviderContainer _container(FakeLocationRepository repository) {
  final container = ProviderContainer(
    overrides: [locationRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  addTearDown(repository.close);
  return container;
}

void main() {
  test('starts idle without touching the location APIs', () {
    final repository = FakeLocationRepository(position: _fix);
    final container = _container(repository);

    expect(
      container.read(locationControllerProvider).status,
      LocationStatus.idle,
    );
    expect(repository.requestCount, 0);
    expect(repository.currentPositionCount, 0);
  });

  test('requests permission on demand and starts tracking', () async {
    final repository = FakeLocationRepository(
      access: LocationAccess.denied,
      position: _fix,
    );
    final container = _container(repository);

    final result = await container
        .read(locationControllerProvider.notifier)
        .locate();

    expect(result, _fix);
    expect(repository.requestCount, 1);
    final state = container.read(locationControllerProvider);
    expect(state.status, LocationStatus.tracking);
    expect(state.position, _fix);
  });

  test('applies streamed updates while tracking', () async {
    final repository = FakeLocationRepository(position: _fix);
    final container = _container(repository);
    await container.read(locationControllerProvider.notifier).locate();

    final next = UserPosition(
      point: const GeoPoint(latitude: 41.12, longitude: 16.87),
      timestamp: DateTime.utc(2026, 1, 1, 0, 0, 5),
    );
    repository.updates.add(next);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(locationControllerProvider).position, next);
  });

  test(
    'reports disabled location services without asking permission',
    () async {
      final repository = FakeLocationRepository(
        serviceEnabled: false,
        access: LocationAccess.denied,
      );
      final container = _container(repository);

      final result = await container
          .read(locationControllerProvider.notifier)
          .locate();

      expect(result, isNull);
      expect(repository.requestCount, 0);
      final state = container.read(locationControllerProvider);
      expect(state.status, LocationStatus.failed);
      expect(state.failure, LocationFailure.serviceDisabled);
    },
  );

  test('reports a denied permission', () async {
    final repository = FakeLocationRepository(
      access: LocationAccess.denied,
      accessAfterRequest: LocationAccess.denied,
    );
    final container = _container(repository);

    await container.read(locationControllerProvider.notifier).locate();

    expect(
      container.read(locationControllerProvider).failure,
      LocationFailure.permissionDenied,
    );
  });

  test('does not prompt again when permanently denied', () async {
    final repository = FakeLocationRepository(
      access: LocationAccess.deniedForever,
    );
    final container = _container(repository);

    await container.read(locationControllerProvider.notifier).locate();

    expect(repository.requestCount, 0);
    expect(
      container.read(locationControllerProvider).failure,
      LocationFailure.permissionDeniedForever,
    );
  });

  test('reports an unavailable fix', () async {
    final repository = FakeLocationRepository(
      positionFailure: LocationFailure.unavailable,
    );
    final container = _container(repository);

    await container.read(locationControllerProvider.notifier).locate();

    expect(
      container.read(locationControllerProvider).failure,
      LocationFailure.unavailable,
    );
  });

  test('opens the settings screen matching the failure', () async {
    final repository = FakeLocationRepository();
    final controller = _container(
      repository,
    ).read(locationControllerProvider.notifier);

    await controller.openSettingsFor(LocationFailure.serviceDisabled);
    await controller.openSettingsFor(LocationFailure.permissionDeniedForever);

    expect(repository.openedSettings, ['location', 'app']);
  });

  test('a stream error stops tracking and clears the position', () async {
    final repository = FakeLocationRepository(position: _fix);
    final container = _container(repository);
    await container.read(locationControllerProvider.notifier).locate();

    repository.updates.addError(
      const LocationException(LocationFailure.serviceDisabled),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(locationControllerProvider);
    expect(state.status, LocationStatus.failed);
    expect(state.position, isNull);
    expect(state.failure, LocationFailure.serviceDisabled);
  });
}
