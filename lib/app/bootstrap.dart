import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/places/data/offline_places_store.dart';
import '../shared/providers/package_info_provider.dart';
import '../shared/providers/shared_preferences_provider.dart';
import 'app.dart';

/// Initializes services and starts the application.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind transparent system bars; screens handle insets themselves.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _registerDataLicenses();

  final (preferences, packageInfo, support) = await (
    SharedPreferences.getInstance(),
    PackageInfo.fromPlatform(),
    // Private app storage, removed with the app and excluded from backup.
    getApplicationSupportDirectory(),
  ).wait;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        packageInfoProvider.overrideWithValue(packageInfo),
        placesDataDirectoryProvider.overrideWithValue(
          Directory('${support.path}/places'),
        ),
      ],
      child: const NaviaApp(),
    ),
  );
}

/// Adds map data licenses to the open-source licenses page, next to the
/// licenses of the Dart and native dependencies.
void _registerDataLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['OpenStreetMap'],
      'Map data © OpenStreetMap contributors.\n\n'
      'OpenStreetMap data is available under the Open Database License '
      '(ODbL) 1.0.\n'
      'https://www.openstreetmap.org/copyright',
    );
    yield const LicenseEntryWithLineBreaks(
      ['OpenMapTiles'],
      'Vector tile schema © OpenMapTiles, licensed under CC-BY 4.0.\n'
      'https://www.openmaptiles.org/',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Navia places data'],
      'Offline place datasets derived from OpenStreetMap, © OpenStreetMap '
      'contributors, available under the Open Database License (ODbL) 1.0.\n'
      'https://github.com/biagio-scaglia/Navia/releases/tag/places-data',
    );
    yield const LicenseEntryWithLineBreaks(
      ['OpenFreeMap'],
      'Map tiles and styles served by OpenFreeMap.\n'
      'https://openfreemap.org/',
    );
  });
}
