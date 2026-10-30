import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/map_control_button.dart';
import '../location_controller.dart';

/// Map control that activates location or recenters on the user.
///
/// It uses the brand gradient only while location is active, so the user can
/// tell at a glance whether Navia is reading the position.
class LocationButton extends StatelessWidget {
  const LocationButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  final LocationStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final (tooltip, icon) = switch (status) {
      LocationStatus.locating => (AppStrings.locating, null),
      LocationStatus.tracking => (
        AppStrings.centerOnMyLocation,
        Icons.my_location_rounded,
      ),
      LocationStatus.failed => (
        AppStrings.showMyLocation,
        Icons.location_disabled_rounded,
      ),
      LocationStatus.idle => (
        AppStrings.showMyLocation,
        Icons.location_searching_rounded,
      ),
    };
    final active = status == LocationStatus.tracking;

    return MapControlButton(
      tooltip: tooltip,
      primary: active,
      onPressed: status == LocationStatus.locating ? null : onPressed,
      child: icon == null
          ? SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
            )
          : Icon(icon, color: active ? null : accent),
    );
  }
}
