import 'package:flutter/material.dart';

import '../../app/theme/navia_tokens.dart';
import '../l10n/app_strings.dart';
import 'navia_icon.dart';

/// Back button drawn with Navia's own arrow. It pops the current route like
/// the system back gesture, so both always behave the same way.
class NaviaBackButton extends StatelessWidget {
  const NaviaBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.back,
      onPressed: () => Navigator.maybePop(context),
      icon: const NaviaIcon(NaviaIcons.arrowBack),
    );
  }
}

/// A [NaviaIcons] glyph centered in a tinted circle, used as the leading
/// visual of list rows and cards.
class NaviaIconBadge extends StatelessWidget {
  const NaviaIconBadge(
    this.icon, {
    super.key,
    this.color,
    this.size = NaviaSizes.iconBadge,
  });

  final NaviaIcons icon;

  /// Icon color; the background is a light tint of it. Defaults to the
  /// primary color.
  final Color? color;

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: NaviaIcon(icon, color: color, size: size * 0.5),
        ),
      ),
    );
  }
}

/// Small round icon button on a tinted background, for secondary actions
/// inside panels (close, save).
class NaviaTonalIconButton extends StatelessWidget {
  const NaviaTonalIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final NaviaIcons icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Uses the primary color, e.g. for a saved favorite.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.onSurface.withValues(alpha: 0.06),
        foregroundColor: selected ? scheme.primary : scheme.onSurface,
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
      ),
      icon: NaviaIcon(icon, size: 20),
    );
  }
}
