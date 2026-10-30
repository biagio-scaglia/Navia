import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/favorites/presentation/favorites_controller.dart';
import 'package:navia/features/favorites/presentation/favorites_screen.dart';
import 'package:navia/features/map/domain/map_style_source.dart';
import 'package:navia/features/map/presentation/map_preferences_controller.dart';
import 'package:navia/features/map/presentation/widgets/map_layers_sheet.dart';
import 'package:navia/shared/models/geo_point.dart';

import 'widget_test_harness.dart';

class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showMapLayersSheet(context),
        child: const Text('apri'),
      ),
    ),
  );
}

void main() {
  testWidgets('map layers sheet changes appearance and 3D view', (
    tester,
  ) async {
    final container = await pumpNaviaWidget(tester, const _SheetLauncher());
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('Aspetto della mappa'), findsOneWidget);
    for (final label in ['Automatico', 'Standard', 'Vivace', 'Essenziale']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Essenziale'));
    await tester.pumpAndSettle();
    expect(
      container.read(mapPreferencesProvider).appearance,
      MapAppearance.minimal,
    );

    await tester.scrollUntilVisible(find.text('Edifici 3D'), 200);
    await tester.tap(find.text('Edifici 3D'));
    await tester.pumpAndSettle();
    expect(container.read(mapPreferencesProvider).buildings3d, isTrue);
  });

  group('FavoritesScreen', () {
    testWidgets('explains the empty state', (tester) async {
      await pumpNaviaWidget(tester, const FavoritesScreen());
      await tester.pumpAndSettle();
      expect(find.text('Nessun preferito'), findsOneWidget);
    });

    testWidgets('lists, deletes and restores favorites', (tester) async {
      final container = await pumpNaviaWidget(tester, const FavoritesScreen());
      await container
          .read(favoritesProvider.notifier)
          .add('Casa', const GeoPoint(latitude: 41.1171, longitude: 16.8719));
      await tester.pumpAndSettle();

      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('41.11710, 16.87190'), findsOneWidget);

      await tester.tap(find.byTooltip('Elimina'));
      await tester.pumpAndSettle();
      expect(find.text('Casa'), findsNothing);
      expect(container.read(favoritesProvider), isEmpty);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.text('Casa'), findsOneWidget);
      expect(container.read(favoritesProvider), hasLength(1));
    });

    testWidgets('returns a favorite for directions', (tester) async {
      FavoritePick? picked;
      final container = await pumpNaviaWidget(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  picked = await FavoritesScreen.open(context),
              child: const Text('apri'),
            ),
          ),
        ),
      );
      await container
          .read(favoritesProvider.notifier)
          .add(
            'Farmacia',
            const GeoPoint(latitude: 41.12, longitude: 16.87),
            category: 'Farmacia',
            address: 'Via Sparano da Bari, 5',
          );
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      expect(find.text('Farmacia · Via Sparano da Bari, 5'), findsOneWidget);
      await tester.tap(find.byTooltip('Indicazioni'));
      await tester.pumpAndSettle();

      expect(picked?.favorite.name, 'Farmacia');
      expect(picked?.directions, isTrue);
    });
  });
}
