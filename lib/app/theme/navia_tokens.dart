import 'package:flutter/material.dart';

/// Raw color tokens of the Navia design system.
///
/// Widgets should not read these directly: use `Theme.of(context).colorScheme`
/// or the [NaviaSurfaces] theme extension instead, so light and dark themes
/// stay consistent.
abstract final class NaviaColors {
  /// Brand blue. Used for fills and icons; text on it must be large or bold.
  static const brand = Color(0xFF1677FF);

  /// Darker brand blue for text-bearing surfaces in the light theme
  /// (5.3:1 contrast against white).
  static const brandDeep = Color(0xFF0B63E5);

  /// Lighter brand blue for the dark theme.
  static const brandLight = Color(0xFF6AA8FF);

  static const aqua = Color(0xFF00BFA6);
  static const aquaLight = Color(0xFF4FE0CB);

  static const backgroundLight = Color(0xFFF5F8FC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceLightTint = Color(0xFFEAF2FD);
  static const inkLight = Color(0xFF0F1B2D);
  static const inkLightMuted = Color(0xFF4A5A70);

  static const backgroundDark = Color(0xFF0B1220);
  static const surfaceDark = Color(0xFF151F30);
  static const surfaceDarkRaised = Color(0xFF1C2940);
  static const inkDark = Color(0xFFE6EDF7);
  static const inkDarkMuted = Color(0xFFA3B1C6);

  /// Destination marker, distinct from error red to avoid alarm.
  static const destination = Color(0xFFE5483B);
  static const destinationDark = Color(0xFFFF7A6B);

  /// Darker outline under the route line, for contrast on light roads.
  static const routeCasing = Color(0xFF0B4FB8);
  static const routeCasingDark = Color(0xFF0B2A5C);

  /// Extruded buildings in the 3D view: warm stone in light maps, slate
  /// blue in dark maps, both muted so routes stay dominant.
  static const building = Color(0xFFDCD6CC);
  static const buildingDark = Color(0xFF2A3754);

  static const error = Color(0xFFD93A3A);
  static const errorDark = Color(0xFFFF8A80);
}

/// Spacing scale, in logical pixels.
abstract final class NaviaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radius scale.
abstract final class NaviaRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;

  /// Top corners of the panel docked to the bottom of the map.
  static const double xl = 28;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Interaction sizing tokens.
abstract final class NaviaSizes {
  /// Minimum touch target recommended by Material and Android guidelines.
  static const double minTouchTarget = 48;

  /// Size of the round floating map controls. Every control column is
  /// this wide, so all control icons share one vertical axis.
  static const double mapControl = 52;

  /// Tinted circle behind leading icons in lists and cards.
  static const double iconBadge = 40;

  /// Maximum width of the bottom panel and top bar on large screens.
  static const double panelMaxWidth = 600;
}

/// Elevation tokens: soft, blue-tinted shadows kept low so floating
/// controls separate from the map without looking heavy.
abstract final class NaviaElevation {
  /// Small controls and chips.
  static const low = [
    BoxShadow(color: Color(0x1F0B3D91), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Floating panels and the search bar.
  static const medium = [
    BoxShadow(color: Color(0x240B3D91), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Panels on dark maps: neutral shadow, no blue tint.
  static const mediumDark = [
    BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// The panel docked to the bottom edge casts its shadow upwards.
  static const docked = [
    BoxShadow(color: Color(0x1F0B3D91), blurRadius: 24, offset: Offset(0, -4)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, -1)),
  ];

  static const dockedDark = [
    BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, -4)),
  ];
}

/// Motion tokens.
abstract final class NaviaDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const camera = Duration(milliseconds: 900);
}
