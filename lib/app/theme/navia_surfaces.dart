import 'package:flutter/material.dart';

import 'navia_tokens.dart';

/// Theme extension describing the surfaces drawn over the map.
///
/// Floating controls are solid, with a hairline border and a soft tinted
/// shadow, so they stay legible on any map style. Only the primary control
/// uses the brand gradient.
@immutable
class NaviaSurfaces extends ThemeExtension<NaviaSurfaces> {
  const NaviaSurfaces({
    required this.floating,
    required this.primaryGradient,
    required this.hairline,
    required this.floatingShadow,
    required this.dockedShadow,
  });

  static const light = NaviaSurfaces(
    floating: NaviaColors.surfaceLight,
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A8DFF), NaviaColors.brandDeep],
    ),
    hairline: Color(0x140F1B2D),
    floatingShadow: NaviaElevation.medium,
    dockedShadow: NaviaElevation.docked,
  );

  static const dark = NaviaSurfaces(
    floating: NaviaColors.surfaceDarkRaised,
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4C9BFF), Color(0xFF1667E0)],
    ),
    hairline: Color(0x1FFFFFFF),
    floatingShadow: NaviaElevation.mediumDark,
    dockedShadow: NaviaElevation.dockedDark,
  );

  /// Background of floating panels and secondary controls.
  final Color floating;

  /// Background of the primary floating control.
  final Gradient primaryGradient;

  /// Thin border that separates surfaces from the map.
  final Color hairline;

  final List<BoxShadow> floatingShadow;

  /// Shadow of the panel docked to the bottom edge.
  final List<BoxShadow> dockedShadow;

  /// Decoration for a floating surface, rounded by [borderRadius] or
  /// [circle] shaped.
  BoxDecoration floatingDecoration({
    BorderRadiusGeometry borderRadius = NaviaRadii.lgAll,
    bool circle = false,
    bool primary = false,
  }) {
    return BoxDecoration(
      color: primary ? null : floating,
      gradient: primary ? primaryGradient : null,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : borderRadius,
      border: primary ? null : Border.all(color: hairline),
      boxShadow: floatingShadow,
    );
  }

  /// Decoration for the panel docked to the bottom of the screen.
  BoxDecoration dockedDecoration() {
    return BoxDecoration(
      color: floating,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(NaviaRadii.xl),
      ),
      border: Border(top: BorderSide(color: hairline)),
      boxShadow: dockedShadow,
    );
  }

  @override
  NaviaSurfaces copyWith({
    Color? floating,
    Gradient? primaryGradient,
    Color? hairline,
    List<BoxShadow>? floatingShadow,
    List<BoxShadow>? dockedShadow,
  }) {
    return NaviaSurfaces(
      floating: floating ?? this.floating,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      hairline: hairline ?? this.hairline,
      floatingShadow: floatingShadow ?? this.floatingShadow,
      dockedShadow: dockedShadow ?? this.dockedShadow,
    );
  }

  @override
  NaviaSurfaces lerp(NaviaSurfaces? other, double t) {
    if (other == null) return this;
    return NaviaSurfaces(
      floating: Color.lerp(floating, other.floating, t)!,
      primaryGradient: Gradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      floatingShadow: BoxShadow.lerpList(
        floatingShadow,
        other.floatingShadow,
        t,
      )!,
      dockedShadow: BoxShadow.lerpList(dockedShadow, other.dockedShadow, t)!,
    );
  }
}

extension NaviaThemeContext on BuildContext {
  /// The [NaviaSurfaces] of the closest theme.
  NaviaSurfaces get naviaSurfaces =>
      Theme.of(this).extension<NaviaSurfaces>() ?? NaviaSurfaces.light;
}
