import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/map_control_button.dart';
import '../location_controller.dart';

/// Primary map control that activates location or recenters on the user.
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

    return MapControlButton(
      tooltip: tooltip,
      primary: true,
      onPressed: status == LocationStatus.locating ? null : onPressed,
      child: icon == null
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Icon(icon),
    );
  }
}
