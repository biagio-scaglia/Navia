import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/platform/system_share.dart';
import 'package:navia/features/navigation/presentation/navigation_controller.dart';
import 'package:navia/features/navigation/presentation/widgets/navigation_sheet.dart';
import 'package:navia/features/places/domain/place_links.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/features/places/presentation/widgets/place_details.dart';
import 'package:navia/features/search/data/photon_geocoding_repository.dart';
import 'package:navia/shared/models/geo_point.dart';

import 'widget_test_harness.dart';

final _pharmacy = Poi(
  ref: const OsmRef(OsmElementType.node, 101),
  point: const GeoPoint(latitude: 41.1201, longitude: 16.8702),
  name: 'Farmacia Centrale',
  category: 'Farmacia',
  address: 'Via Sparano da Bari, 5 · Bari',
  openingHours: 'Mo-Sa 08:30-20:00',
  website: PlaceLinks.website('farmaciacentrale.example.it'),
  phone: '+39 080 5211111',
  wheelchair: WheelchairAccess.limited,
);

void main() {
  testWidgets('shows only the details the place has', (tester) async {
    await pumpNaviaWidget(
      tester,
      Scaffold(
        body: ListView(
          children: [
            PlaceDetailsList(
              place: _pharmacy,
              // Monday 2 November 2026, 10:00 in Bari.
              now: DateTime.utc(2026, 11, 2, 9),
            ),
            const PlaceDetailsList(
              place: Poi(
                ref: OsmRef(OsmElementType.way, 7),
                point: GeoPoint(latitude: 41.12, longitude: 16.87),
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Mo-Sa 08:30-20:00'), findsOneWidget);
    expect(find.text('Aperto ora'), findsOneWidget);
    expect(find.text('Accessibilità limitata'), findsOneWidget);
    expect(find.text('+39 080 5211111'), findsOneWidget);
    expect(find.text('farmaciacentrale.example.it'), findsOneWidget);
    // The unnamed place only links to its OpenStreetMap object.
    expect(find.text('Vedi su OpenStreetMap'), findsNWidgets(2));
    expect(find.text('Orari'), findsOneWidget);
    expect(find.text('Cucina'), findsNothing);
  });

  testWidgets('shows the raw hours without a badge when not computable', (
    tester,
  ) async {
    await pumpNaviaWidget(
      tester,
      const Scaffold(
        body: PlaceDetailsList(
          place: Poi(
            ref: OsmRef(OsmElementType.node, 1),
            point: GeoPoint(latitude: 41.12, longitude: 16.87),
            openingHours: 'Mo-Fr 09:00-18:00; SH off',
          ),
        ),
      ),
    );

    expect(find.text('Mo-Fr 09:00-18:00; SH off'), findsOneWidget);
    expect(find.text('Aperto ora'), findsNothing);
    expect(find.text('Chiuso ora'), findsNothing);
  });

  testWidgets('the place card shares and copies the selected place', (
    tester,
  ) async {
    final shared = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemShare.channel,
      (call) async {
        shared.add(call.arguments);
        return true;
      },
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

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
      overrides: [geocodingRepositoryProvider.overrideWithValue(null)],
    );
    container
        .read(navigationControllerProvider.notifier)
        .selectPlace(_pharmacy);
    await tester.pumpAndSettle();

    expect(find.text('Farmacia Centrale'), findsOneWidget);
    expect(find.text('FARMACIA'), findsOneWidget);
    expect(find.text('Via Sparano da Bari, 5 · Bari'), findsOneWidget);

    await tester.tap(find.text('Condividi'));
    await tester.pumpAndSettle();
    final arguments = shared.single! as Map;
    expect(arguments['subject'], 'Farmacia Centrale');
    expect(
      arguments['text'],
      PlaceLinks.shareText(
        point: _pharmacy.point,
        name: 'Farmacia Centrale',
        address: 'Via Sparano da Bari, 5 · Bari',
      ),
    );

    await tester.tap(find.text('Copia coordinate'));
    await tester.pumpAndSettle();
    expect(copied, '41.12010, 16.87020');
    expect(find.text('Coordinate copiate.'), findsOneWidget);
  });
}
