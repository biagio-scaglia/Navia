import 'package:flutter/material.dart';

import '../../features/map/presentation/map_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';

/// Resolves [AppRoutes] to pages.
Route<void>? onGenerateRoute(RouteSettings settings) {
  final Widget? page = switch (settings.name) {
    AppRoutes.map => const MapScreen(),
    AppRoutes.settings => const SettingsScreen(),
    _ => null,
  };
  if (page == null) return null;
  return MaterialPageRoute<void>(builder: (_) => page, settings: settings);
}
