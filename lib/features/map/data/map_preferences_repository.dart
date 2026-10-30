import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import '../domain/map_style_source.dart';

/// Stores map display preferences on the device.
class MapPreferencesRepository {
  MapPreferencesRepository(this._preferences);

  static const appearanceKey = 'map.appearance';
  static const buildings3dKey = 'map.buildings3d';

  final SharedPreferences _preferences;

  MapAppearance loadAppearance() =>
      MapAppearance.fromStorage(_preferences.getString(appearanceKey));

  Future<void> saveAppearance(MapAppearance appearance) =>
      _preferences.setString(appearanceKey, appearance.name);

  bool loadBuildings3d() => _preferences.getBool(buildings3dKey) ?? false;

  Future<void> saveBuildings3d(bool enabled) =>
      _preferences.setBool(buildings3dKey, enabled);
}

final mapPreferencesRepositoryProvider = Provider<MapPreferencesRepository>(
  (ref) => MapPreferencesRepository(ref.watch(sharedPreferencesProvider)),
);
