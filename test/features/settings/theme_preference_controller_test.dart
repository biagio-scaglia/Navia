import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/settings/data/settings_repository.dart';
import 'package:navia/features/settings/domain/theme_preference.dart';
import 'package:navia/features/settings/presentation/theme_preference_controller.dart';
import 'package:navia/shared/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> createContainer([
  Map<String, Object> initialValues = const {},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ThemePreference', () {
    test('maps to the matching ThemeMode', () {
      expect(ThemePreference.system.themeMode, ThemeMode.system);
      expect(ThemePreference.light.themeMode, ThemeMode.light);
      expect(ThemePreference.dark.themeMode, ThemeMode.dark);
    });

    test('falls back to system for missing or unknown values', () {
      expect(ThemePreference.fromStorage(null), ThemePreference.system);
      expect(ThemePreference.fromStorage('sepia'), ThemePreference.system);
      expect(ThemePreference.fromStorage('dark'), ThemePreference.dark);
    });
  });

  group('ThemePreferenceController', () {
    test('defaults to the system theme', () async {
      final container = await createContainer();

      expect(container.read(themePreferenceProvider), ThemePreference.system);
    });

    test('restores the stored preference', () async {
      final container = await createContainer({
        SettingsRepository.themeKey: 'light',
      });

      expect(container.read(themePreferenceProvider), ThemePreference.light);
    });

    test('persists a new selection', () async {
      final container = await createContainer();

      await container
          .read(themePreferenceProvider.notifier)
          .select(ThemePreference.dark);

      expect(container.read(themePreferenceProvider), ThemePreference.dark);
      final preferences = container.read(sharedPreferencesProvider);
      expect(preferences.getString(SettingsRepository.themeKey), 'dark');
    });
  });
}
