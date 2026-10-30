import 'package:flutter/material.dart';

import '../../app/theme/navia_surfaces.dart';
import '../../app/theme/navia_tokens.dart';

/// Round floating button used for map controls.
///
/// The [tooltip] doubles as the accessibility label.
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.primary = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  /// Uses the brand gradient, for the main action on screen.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = NaviaSizes.mapControl;
    const shape = CircleBorder();

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: context.naviaSurfaces.floatingDecoration(
              circle: true,
              primary: primary,
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: shape,
                onTap: onPressed,
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: primary ? Colors.white : scheme.onSurface,
                    size: 24,
                  ),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
