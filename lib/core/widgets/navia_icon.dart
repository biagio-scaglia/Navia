import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Navia's own icon set: 24×24 grid, 2px rounded strokes.
///
/// The SVG sources live in `assets/icons/`, drawn in black and tinted at
/// runtime, so a single file serves every color and theme.
enum NaviaIcons {
  arrowBack('arrow_back'),
  bike,
  car,
  check,
  chevronDown('chevron_down'),
  chevronRight('chevron_right'),
  chevronUp('chevron_up'),
  close,
  cloudOff('cloud_off'),
  code,
  copyright,
  cube,
  destination,
  directions,
  document,
  edit,
  externalLink('external_link'),
  info,
  layers,
  locate,
  locateFixed('locate_fixed'),
  locateOff('locate_off'),
  origin,
  refresh,
  route,
  search,
  settings,
  shield,
  star,
  starFilled('star_filled'),
  swap,
  themeDark('theme_dark'),
  themeLight('theme_light'),
  themeSystem('theme_system'),
  trash,
  walk;

  const NaviaIcons([this._file]);

  final String? _file;

  String get asset => 'assets/icons/${_file ?? name}.svg';
}

/// Draws a [NaviaIcons] glyph, sized and colored like [Icon] by default.
class NaviaIcon extends StatelessWidget {
  const NaviaIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final NaviaIcons icon;
  final double? size;
  final Color? color;

  /// Announced by screen readers; decorative icons leave it null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = this.size ?? iconTheme.size ?? 24;
    final color = this.color ?? iconTheme.color ?? const Color(0xFF000000);
    final opacity = iconTheme.opacity ?? 1;

    return SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color.withValues(alpha: color.a * opacity),
        BlendMode.srcIn,
      ),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
