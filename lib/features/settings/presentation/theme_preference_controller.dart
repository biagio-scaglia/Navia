import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/theme_preference.dart';

/// Exposes the current [ThemePreference] and persists changes.
class ThemePreferenceController extends Notifier<ThemePreference> {
  @override
  ThemePreference build() => ref.watch(settingsRepositoryProvider).loadTheme();

  Future<void> select(ThemePreference preference) async {
    if (preference == state) return;
    state = preference;
    await ref.read(settingsRepositoryProvider).saveTheme(preference);
  }
}

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceController, ThemePreference>(
      ThemePreferenceController.new,
    );
