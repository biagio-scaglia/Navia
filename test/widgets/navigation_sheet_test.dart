import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/features/favorites/presentation/favorites_controller.dart';
import 'package:navia/features/navigation/data/osrm_routing_repository.dart';
import 'package:navia/features/navigation/domain/navigation_models.dart';
import 'package:navia/features/navigation/domain/routing_repository.dart';
import 'package:navia/features/navigation/presentation/navigation_controller.dart';
import 'package:navia/features/navigation/presentation/widgets/navigation_sheet.dart';
import 'package:navia/features/search/data/photon_geocoding_repository.dart';
import 'package:navia/shared/models/geo_point.dart';

import 'widget_test_harness.dart';

class _Router implements RoutingRepository {
  _Router(this.supportedModes, {this.failure});

  @override
  final Set<TravelMode> supportedModes;
  final ServiceFailure? failure;

  @override
  Future<NavRoute> route({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  }) async {
    final failure = this.failure;
    if (failure != null) throw ServiceException(failure);
    return NavRoute(
      mode: mode,
      geometry: [origin, destination],
      distanceMeters: 1670,
      duration: const Duration(minutes: 3),
    );
  }
}

const _point = PointWaypoint(GeoPoint(latitude: 41.1171, longitude: 16.8719));

late ProviderContainer _container;

Future<NavigationController> _pump(
  WidgetTester tester, {
  Set<TravelMode> modes = const {...TravelMode.values},
  ServiceFailure? failure,
}) async {
  final container = await pumpNaviaWidget(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: NavigationSheet(
          mapCenter: () async =>
              const GeoPoint(latitude: 41.12, longitude: 16.87),
          onFocusArticle: (_) {},
        ),
      ),
    ),
    overrides: [
      routingRepositoryProvider.overrideWithValue(
        _Router(modes, failure: failure),
      ),
      geocodingRepositoryProvider.overrideWithValue(null),
    ],
  );
  _container = container;
  return container.read(navigationControllerProvider.notifier);
}

void main() {
  testWidgets('offers directions when nothing is selected', (tester) async {
    await _pump(tester);
    expect(find.text('Dove vuoi andare?'), findsOneWidget);
  });

  testWidgets('is hidden when routing is not configured', (tester) async {
    await _pump(tester, modes: const {});
    expect(find.text('Dove vuoi andare?'), findsNothing);
  });

  testWidgets('shows a map selection with coordinates and actions', (
    tester,
  ) async {
    final controller = await _pump(tester);
    controller.select(_point);
    await tester.pumpAndSettle();

    expect(find.text('Punto selezionato'), findsOneWidget);
    expect(find.textContaining('41.11710, 16.87190'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Indicazioni'));
    await tester.pumpAndSettle();

    expect(find.text('La tua posizione'), findsOneWidget);
    expect(find.text('Punto sulla mappa'), findsOneWidget);
    // The route is requested right away, without a separate step.
    expect(find.text('3 min'), findsOneWidget);
    expect(find.text('Calcola percorso'), findsNothing);
  });

  testWidgets('shows the route as soon as a destination is chosen', (
    tester,
  ) async {
    final controller = await _pump(tester);
    controller
      ..setOrigin(
        const PointWaypoint(GeoPoint(latitude: 41.12, longitude: 16.86)),
      )
      ..select(_point);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Indicazioni'));
    await tester.pumpAndSettle();

    expect(find.text('3 min'), findsOneWidget);
    expect(find.text('1,7 km'), findsOneWidget);
    expect(find.textContaining('Arrivo alle'), findsOneWidget);
  });

  testWidgets('calculates and summarizes a route', (tester) async {
    final controller = await _pump(tester);
    controller
      ..setOrigin(
        const PointWaypoint(GeoPoint(latitude: 41.12, longitude: 16.86)),
      )
      ..setDestination(_point);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calcola percorso'));
    await tester.pumpAndSettle();

    expect(find.text('3 min'), findsOneWidget);
    expect(find.text('1,7 km'), findsOneWidget);
  });

  testWidgets('explains routing failures and offers a retry', (tester) async {
    final controller = await _pump(
      tester,
      failure: ServiceFailure.noConnection,
    );
    controller
      ..setOrigin(
        const PointWaypoint(GeoPoint(latitude: 41.12, longitude: 16.86)),
      )
      ..setDestination(_point);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calcola percorso'));
    await tester.pumpAndSettle();

    expect(find.text('Percorso non disponibile'), findsOneWidget);
    expect(find.textContaining('Nessuna connessione'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
  });

  testWidgets('hides the mode selector when only one mode is offered', (
    tester,
  ) async {
    final controller = await _pump(tester, modes: const {TravelMode.driving});
    controller.setDestination(_point);
    await tester.pumpAndSettle();

    expect(find.text('A piedi'), findsNothing);
  });

  testWidgets('saves the selection as a named favorite', (tester) async {
    final controller = await _pump(tester);
    controller.select(
      const PointWaypoint(
        GeoPoint(latitude: 41.1225, longitude: 16.8721),
        label: 'Teatro Petruzzelli',
        category: 'Teatro',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEATRO'), findsOneWidget);
    await tester.tap(find.byTooltip('Salva nei preferiti'));
    await tester.pumpAndSettle();
    expect(find.text('Teatro Petruzzelli'), findsWidgets);

    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    final favorites = _container.read(favoritesProvider);
    expect(favorites.single.name, 'Teatro Petruzzelli');
    expect(find.byTooltip('Salvato nei preferiti'), findsOneWidget);
  });
}
