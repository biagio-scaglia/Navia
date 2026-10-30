import 'package:flutter/material.dart';

import '../../app/theme/navia_surfaces.dart';
import '../../app/theme/navia_tokens.dart';

/// A soft floating panel placed over the map.
class FloatingSurface extends StatelessWidget {
  const FloatingSurface({
    super.key,
    required this.child,
    this.borderRadius = NaviaRadii.lgAll,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: context.naviaSurfaces.floatingDecoration(
        borderRadius: borderRadius,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
