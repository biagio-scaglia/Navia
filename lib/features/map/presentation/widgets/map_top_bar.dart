import 'package:flutter/material.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/floating_surface.dart';
import '../../../../core/widgets/navia_logo.dart';

/// Floating header with the Navia brand and the settings entry point.
class MapTopBar extends StatelessWidget {
  const MapTopBar({super.key, required this.onOpenSettings});

  static const height = 60.0;

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return FloatingSurface(
      padding: const EdgeInsets.only(
        left: NaviaSpacing.md,
        right: NaviaSpacing.xs,
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Semantics(header: true, child: const NaviaWordmark()),
            const Spacer(),
            IconButton(
              tooltip: AppStrings.settings,
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
