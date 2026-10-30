import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/features/location/data/geolocator_location_repository.dart';
import 'package:navia/features/location/domain/location_models.dart';
import 'package:navia/features/navigation/data/osrm_routing_repository.dart';
import 'package:navia/features/navigation/domain/navigation_models.dart';
import 'package:navia/features/navigation/domain/routing_repository.dart';
import 'package:navia/features/navigation/presentation/navigation_controller.dart';
import 'package:navia/shared/models/geo_point.dart';

import '../location/fake_location_repository.dart';

const _a = PointWaypoint(GeoPoint(latitude: 41.1171, longitude: 16.8719));
const _b = PointWaypoint(
  GeoPoint(latitude: 41.1253, longitude: 16.8667),
  label: 'Teatro Petruzzelli',
);
const _gps = GeoPoint(latitude: 41.12, longitude: 16.86);

/// Router whose responses are completed manually by the test.
class _ControlledRouter implements RoutingRepository {
  _ControlledRouter([this.supportedModes = const {...TravelMode.values}]);

  @override
  final Set<TravelMode> supportedModes;

  final List<({GeoPoint origin, GeoPoint destination, TravelMode mode})>
  requests = [];
  final List<Completer<NavRoute>> pending = [];

  @override
  Future<NavRoute> route({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) {
    requests.add((origin: origin, destination: destination, mode: mode));
    final completer = Completer<NavRoute>();
    pending.add(completer);
    return completer.future;
  }

  void completeLast() {
    final request = requests.last;
    pending.last.complete(
      NavRoute(
        mode: request.mode,
        geometry: [request.origin, request.destination],
        distanceMeters: 1200,
        duration: const Duration(minutes: 4),
      ),
    );
  }
}

typedef _Setup = ({
  ProviderContainer container,
  _ControlledRouter router,
  FakeLocationRepository location,
});

_Setup _setup({
  Set<TravelMode> modes = const {...TravelMode.values},
  FakeLocationRepository? location,
}) {
  final router = _ControlledRouter(modes);
  final locationRepository =
      location ??
      FakeLocationRepository(
        position: UserPosition(point: _gps, timestamp: DateTime.utc(2026)),
      );
  final container = ProviderContainer(
    overrides: [
      routingRepositoryProvider.overrideWithValue(router),
      locationRepositoryProvider.overrideWithValue(locationRepository),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(locationRepository.close);
  return (container: container, router: router, location: locationRepository);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('selection becomes destination with the user location as origin', () {
    final (:container, router: _, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier);

    controller
      ..select(_b)
      ..useSelectionAsDestination();

    final state = container.read(navigationControllerProvider);
    expect(state.selection, isNull);
    expect(state.origin, const CurrentLocationWaypoint());
    expect(state.destination, _b);
    expect(state.canCalculate, isTrue);
  });

  test('clearing a selection keeps the planned route points', () {
    final (:container, router: _, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..select(_b)
      ..clearSelection();

    expect(controller.state.selection, isNull);
    expect(controller.state.origin, _a);
  });

  test('swaps origin and destination', () {
    final (:container, router: _, location: _) = _setup();
    container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..setDestination(_b)
      ..swap();

    final state = container.read(navigationControllerProvider);
    expect(state.origin, _b);
    expect(state.destination, _a);
  });

  test('calculates a route through loading and ready states', () async {
    final (:container, :router, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..setDestination(_b);

    final calculation = controller.calculate();
    await _flush();
    expect(
      container.read(navigationControllerProvider).routeStatus,
      RouteStatus.loading,
    );
    router.completeLast();
    await calculation;

    final state = container.read(navigationControllerProvider);
    expect(state.routeStatus, RouteStatus.ready);
    expect(state.route?.distanceMeters, 1200);
    expect(router.requests.single.origin, _a.point);
    expect(router.requests.single.mode, TravelMode.driving);
  });

  test('resolves the user location as origin when calculating', () async {
    final (:container, :router, :location) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(const CurrentLocationWaypoint())
      ..setDestination(_b);
    expect(location.currentPositionCount, 0);

    final calculation = controller.calculate();
    await _flush();
    router.completeLast();
    await calculation;

    expect(router.requests.single.origin, _gps);
  });

  test('reports an unavailable user location', () async {
    final (:container, :router, location: _) = _setup(
      location: FakeLocationRepository(access: LocationAccess.deniedForever),
    );
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(const CurrentLocationWaypoint())
      ..setDestination(_b);

    await controller.calculate();

    final state = container.read(navigationControllerProvider);
    expect(state.routeStatus, RouteStatus.failed);
    expect(
      state.error,
      const RouteLocationError(LocationFailure.permissionDeniedForever),
    );
    expect(router.requests, isEmpty);
  });

  test('rejects identical origin and destination', () async {
    final (:container, :router, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..setDestination(_a);

    await controller.calculate();

    expect(
      container.read(navigationControllerProvider).error,
      const RouteSamePointsError(),
    );
    expect(router.requests, isEmpty);
  });

  test('reports routing failures', () async {
    final (:container, :router, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..setDestination(_b);

    final calculation = controller.calculate();
    await _flush();
    router.pending.last.completeError(
      const ServiceException(ServiceFailure.noResult),
    );
    await calculation;

    expect(
      container.read(navigationControllerProvider).error,
      const RouteServiceError(ServiceFailure.noResult),
    );
  });

  test('discards a response after the destination changed', () async {
    final (:container, :router, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..setDestination(_b);

    final calculation = controller.calculate();
    await _flush();
    controller.setDestination(
      const PointWaypoint(GeoPoint(latitude: 41.1, longitude: 16.9)),
    );
    router.completeLast();
    await calculation;

    final state = container.read(navigationControllerProvider);
    expect(state.routeStatus, RouteStatus.idle);
    expect(state.route, isNull);
  });

  test('changing mode recalculates a shown route', () async {
    final (:container, :router, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..setDestination(_b);
    final first = controller.calculate();
    await _flush();
    router.completeLast();
    await first;

    final second = controller.setMode(TravelMode.walking);
    await _flush();
    router.completeLast();
    await second;

    expect(router.requests.map((r) => r.mode), [
      TravelMode.driving,
      TravelMode.walking,
    ]);
    expect(
      container.read(navigationControllerProvider).route?.mode,
      TravelMode.walking,
    );
  });

  test('ignores unsupported travel modes', () async {
    final (:container, router: _, location: _) = _setup(
      modes: {TravelMode.driving},
    );
    final controller = container.read(navigationControllerProvider.notifier);

    await controller.setMode(TravelMode.cycling);

    expect(
      container.read(navigationControllerProvider).mode,
      TravelMode.driving,
    );
  });

  test('clear ends route planning', () async {
    final (:container, :router, location: _) = _setup();
    final controller = container.read(navigationControllerProvider.notifier)
      ..setOrigin(_a)
      ..setDestination(_b);
    final calculation = controller.calculate();
    await _flush();
    router.completeLast();
    await calculation;

    controller.clear();

    final state = container.read(navigationControllerProvider);
    expect(state.isPlanning, isFalse);
    expect(state.route, isNull);
  });
}
