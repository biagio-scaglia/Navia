import 'package:flutter/material.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/floating_surface.dart';

/// Stacked zoom in/out buttons, for one-handed use and accessibility.
class MapZoomControls extends StatelessWidget {
  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    return FloatingSurface(
      borderRadius: const BorderRadius.all(
        Radius.circular(NaviaSizes.mapControl / 2),
      ),
      child: SizedBox(
        width: NaviaSizes.mapControl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZoomButton(
              icon: Icons.add_rounded,
              tooltip: AppStrings.zoomIn,
              onPressed: onZoomIn,
            ),
            const Divider(indent: NaviaSpacing.md, endIndent: NaviaSpacing.md),
            _ZoomButton(
              icon: Icons.remove_rounded,
              tooltip: AppStrings.zoomOut,
              onPressed: onZoomOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: NaviaSizes.mapControl,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
