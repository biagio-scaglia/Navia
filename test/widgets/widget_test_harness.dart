import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/app/theme/navia_theme.dart';
import 'package:navia/features/location/data/geolocator_location_repository.dart';
import 'package:navia/features/location/domain/location_models.dart';
import 'package:navia/features/places/data/offline_places_store.dart';
import 'package:navia/shared/models/geo_point.dart';
import 'package:navia/shared/providers/package_info_provider.dart';
import 'package:navia/shared/providers/shared_preferences_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/location/fake_location_repository.dart';

/// Pumps [child] inside the app theme, Italian localizations and a
/// [ProviderScope] whose platform services are replaced by fakes.
Future<ProviderContainer> pumpNaviaWidget(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final location = FakeLocationRepository(
    position: UserPosition(
      point: const GeoPoint(latitude: 41.1253, longitude: 16.8667),
      timestamp: DateTime.utc(2026),
    ),
  );
  addTearDown(location.close);
  final placesDirectory = Directory.systemTemp.createTempSync('navia_test_');
  addTearDown(() => placesDirectory.deleteSync(recursive: true));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        packageInfoProvider.overrideWithValue(
          PackageInfo(
            appName: 'Navia',
            packageName: 'io.github.biagioscaglia.navia',
            version: '0.4.1',
            buildNumber: '5',
          ),
        ),
        locationRepositoryProvider.overrideWithValue(location),
        placesDataDirectoryProvider.overrideWithValue(placesDirectory),
        ...overrides,
      ],
      child: MaterialApp(
        theme: NaviaTheme.light,
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byWidget(child)));
}
