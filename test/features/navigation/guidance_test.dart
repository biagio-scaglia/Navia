import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/platform/voice_guide.dart';
import 'package:navia/features/location/data/geolocator_location_repository.dart';
import 'package:navia/features/location/domain/location_models.dart';
import 'package:navia/features/navigation/data/osrm_routing_repository.dart';
import 'package:navia/features/navigation/domain/guidance_tracker.dart';
import 'package:navia/features/navigation/domain/navigation_models.dart';
import 'package:navia/features/navigation/domain/routing_repository.dart';
import 'package:navia/features/navigation/presentation/guidance_controller.dart';
import 'package:navia/features/navigation/presentation/navigation_controller.dart';
import 'package:navia/features/navigation/presentation/route_instructions.dart';
import 'package:navia/shared/models/geo_point.dart';

import '../location/fake_location_repository.dart';

// A straight street north, then a right turn east, in Bari.
const _start = GeoPoint(latitude: 41.1100, longitude: 16.8700);
const _turn = GeoPoint(latitude: 41.1145, longitude: 16.8700);
const _end = GeoPoint(latitude: 41.1145, longitude: 16.8760);

GeoPoint _north(double meters) =>
    GeoPoint(latitude: 41.1100 + meters / 111000, longitude: 16.8700);

const _route = NavRoute(
  mode: TravelMode.driving,
  geometry: [_start, _turn, _end],
  distanceMeters: 1000,
  duration: Duration(minutes: 3),
  steps: [
    RouteStep(
      kind: ManeuverKind.depart,
      location: _start,
      distanceMeters: 500,
      streetName: 'Via Sparano',
    ),
    RouteStep(
      kind: ManeuverKind.turn,
      location: _turn,
      distanceMeters: 500,
      direction: ManeuverDirection.right,
      streetName: 'Corso Cavour',
    ),
    RouteStep(kind: ManeuverKind.arrive, location: _end, distanceMeters: 0),
  ],
);

GuidanceTracker _tracker() => GuidanceTracker(
  _route,
  describe: RouteInstructions.text,
  describeAhead: RouteInstructions.spokenAhead,
);

class _Voice implements VoiceGuide {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

class _Router implements RoutingRepository {
  @override
  Set<TravelMode> get supportedModes => {TravelMode.driving};

  @override
  Future<NavRoute> route({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) async => _route;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuidanceTracker', () {
    test('announces a maneuver ahead, then when it is near', () {
      final tracker = _tracker();
      expect(tracker.departure, 'Parti su Via Sparano');

      final far = tracker.update(_north(0));
      expect(far.nextStepIndex, 1);
      expect(far.announcement, isNull);

      final ahead = tracker.update(_north(150));
      expect(
        ahead.announcement,
        'Tra 350 metri, svolta a destra in Corso Cavour',
      );

      expect(tracker.update(_north(200)).announcement, isNull);

      final near = tracker.update(_north(460));
      expect(near.announcement, 'Svolta a destra in Corso Cavour');
      expect(near.remainingMeters, greaterThan(500));
    });

    test('moves to the next maneuver and detects arrival', () {
      final tracker = _tracker();
      final turned = tracker.update(_turn);
      expect(turned.nextStepIndex, 2);

      final arrived = tracker.update(_end);
      expect(arrived.arrived, isTrue);
      expect(arrived.announcement, 'Sei arrivato a destinazione');
    });

    test('reports off route after two updates away from the path', () {
      final tracker = _tracker();
      const away = GeoPoint(latitude: 41.1120, longitude: 16.8730);
      expect(tracker.update(away).offRoute, isFalse);
      expect(tracker.update(away).offRoute, isTrue);
      expect(tracker.update(_north(100)).offRoute, isFalse);
    });

    test('measures the distance to a path', () {
      final onPath = GuidanceTracker.distanceToPath(_north(200), [
        _start,
        _turn,
      ]);
      expect(onPath, lessThan(1));
      final beside = GuidanceTracker.distanceToPath(
        const GeoPoint(latitude: 41.1120, longitude: 16.8712),
        [_start, _turn],
      );
      expect(beside, closeTo(100, 5));
    });
  });

  test('the controller speaks the departure and follows positions', () async {
    final voice = _Voice();
    final location = FakeLocationRepository(
      position: UserPosition(point: _start, timestamp: DateTime.utc(2026)),
    );
    final container = ProviderContainer(
      overrides: [
        voiceGuideProvider.overrideWithValue(voice),
        locationRepositoryProvider.overrideWithValue(location),
        routingRepositoryProvider.overrideWithValue(_Router()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(location.close);

    final navigation = container.read(navigationControllerProvider.notifier)
      ..setOrigin(const CurrentLocationWaypoint())
      ..setDestination(const PointWaypoint(_end));
    await navigation.calculate();
    final guidance = container.read(guidanceProvider.notifier);

    await guidance.start();
    expect(container.read(guidanceProvider).active, isTrue);
    expect(voice.spoken.first, 'Parti su Via Sparano');

    location.updates.add(
      UserPosition(point: _north(460), timestamp: DateTime.utc(2026)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(voice.spoken.last, 'Svolta a destra in Corso Cavour');
    expect(
      container.read(guidanceProvider).nextStep?.streetName,
      'Corso Cavour',
    );

    guidance.toggleMuted();
    for (final point in [_turn, _end]) {
      location.updates.add(
        UserPosition(point: point, timestamp: DateTime.utc(2026)),
      );
      await Future<void>.delayed(Duration.zero);
    }
    // Muted: nothing more is spoken; arrival ends the guidance.
    expect(voice.spoken.last, 'Svolta a destra in Corso Cavour');
    expect(container.read(guidanceProvider).active, isFalse);
  });
}
