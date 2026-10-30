import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/settings/data/settings_repository.dart';
import 'package:navia/features/settings/domain/theme_preference.dart';
import 'package:navia/features/settings/presentation/settings_screen.dart';
import 'package:navia/features/settings/presentation/theme_preference_controller.dart';
import 'package:navia/shared/providers/shared_preferences_provider.dart';

import 'widget_test_harness.dart';

void main() {
  testWidgets('selecting a theme updates and persists the preference', (
    tester,
  ) async {
    final container = await pumpNaviaWidget(tester, const SettingsScreen());

    await tester.tap(find.text('Scuro'));
    await tester.pumpAndSettle();

    expect(container.read(themePreferenceProvider), ThemePreference.dark);
    expect(
      container
          .read(sharedPreferencesProvider)
          .getString(SettingsRepository.themeKey),
      'dark',
    );
  });

  testWidgets('shows permission state, services and version', (tester) async {
    await pumpNaviaWidget(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Consentito'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('0.2.0 (2)'), 300);
    expect(find.text('Ricerca: Photon (komoot)'), findsOneWidget);
    expect(find.text('Percorsi: OSRM (FOSSGIS)'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });
}
