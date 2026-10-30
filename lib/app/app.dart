import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/theme_preference_controller.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/navia_theme.dart';

class NaviaApp extends ConsumerWidget {
  const NaviaApp({super.key});

  static const _locale = Locale('it', 'IT');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themePreferenceProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: NaviaTheme.light,
      darkTheme: NaviaTheme.dark,
      themeMode: themePreference.themeMode,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.map,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
