import 'package:flutter/material.dart';

/// The theme chosen by the user.
enum ThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  /// Parses a stored value, falling back to [system] for unknown input.
  static ThemePreference fromStorage(String? value) => ThemePreference.values
      .firstWhere((p) => p.name == value, orElse: () => ThemePreference.system);
}
