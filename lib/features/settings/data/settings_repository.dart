import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import '../domain/theme_preference.dart';

/// Stores user settings on the device. Nothing leaves the device.
class SettingsRepository {
  SettingsRepository(this._preferences);

  static const themeKey = 'settings.theme';

  final SharedPreferences _preferences;

  ThemePreference loadTheme() =>
      ThemePreference.fromStorage(_preferences.getString(themeKey));

  Future<void> saveTheme(ThemePreference preference) =>
      _preferences.setString(themeKey, preference.name);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);
