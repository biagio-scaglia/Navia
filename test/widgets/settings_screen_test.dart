import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/l10n/privacy_policy.dart';
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

    await tester.scrollUntilVisible(find.text('0.8.0 (7)'), 300);
    expect(find.text('Ricerca: Photon (komoot)'), findsOneWidget);
    expect(find.text('Percorsi: OSRM (FOSSGIS)'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });

  testWidgets('opens the privacy policy with its summary', (tester) async {
    await pumpNaviaWidget(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    final entry = find.text('Informativa sulla privacy');
    await tester.scrollUntilVisible(entry, 300);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('In breve'), findsOneWidget);
    expect(find.text(PrivacyPolicy.summary.first), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dati inviati a servizi esterni'),
      300,
    );
    expect(find.text('Dati inviati a servizi esterni'), findsOneWidget);
  });
}
