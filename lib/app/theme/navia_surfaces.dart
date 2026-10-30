import 'package:flutter/material.dart';

import 'navia_tokens.dart';

/// Theme extension describing Navia's floating surfaces.
///
/// It carries the restrained gradients, highlight borders and tinted shadows
/// that give the floating map controls their soft, slightly glossy look.
@immutable
class NaviaSurfaces extends ThemeExtension<NaviaSurfaces> {
  const NaviaSurfaces({
    required this.floatingGradient,
    required this.primaryGradient,
    required this.highlightBorder,
    required this.floatingShadow,
  });

  static const light = NaviaSurfaces(
    floatingGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [NaviaColors.surfaceLight, NaviaColors.surfaceLightTint],
    ),
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A8DFF), NaviaColors.brandDeep],
    ),
    highlightBorder: Color(0xCCFFFFFF),
    floatingShadow: [
      BoxShadow(color: Color(0x241677FF), blurRadius: 18, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
  );

  static const dark = NaviaSurfaces(
    floatingGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [NaviaColors.surfaceDarkRaised, NaviaColors.surfaceDark],
    ),
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4C9BFF), Color(0xFF1667E0)],
    ),
    highlightBorder: Color(0x1FFFFFFF),
    floatingShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
    ],
  );

  /// Background of floating panels and secondary controls.
  final Gradient floatingGradient;

  /// Background of the primary floating control.
  final Gradient primaryGradient;

  /// Thin top-lit border that reads as a soft highlight.
  final Color highlightBorder;

  final List<BoxShadow> floatingShadow;

  /// Decoration for a floating surface, rounded by [borderRadius] or
  /// [circle] shaped.
  BoxDecoration floatingDecoration({
    BorderRadiusGeometry borderRadius = NaviaRadii.lgAll,
    bool circle = false,
    bool primary = false,
  }) {
    return BoxDecoration(
      gradient: primary ? primaryGradient : floatingGradient,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : borderRadius,
      border: Border.all(color: highlightBorder),
      boxShadow: floatingShadow,
    );
  }

  @override
  NaviaSurfaces copyWith({
    Gradient? floatingGradient,
    Gradient? primaryGradient,
    Color? highlightBorder,
    List<BoxShadow>? floatingShadow,
  }) {
    return NaviaSurfaces(
      floatingGradient: floatingGradient ?? this.floatingGradient,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      highlightBorder: highlightBorder ?? this.highlightBorder,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  NaviaSurfaces lerp(NaviaSurfaces? other, double t) {
    if (other == null) return this;
    return NaviaSurfaces(
      floatingGradient: Gradient.lerp(
        floatingGradient,
        other.floatingGradient,
        t,
      )!,
      primaryGradient: Gradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
      highlightBorder: Color.lerp(highlightBorder, other.highlightBorder, t)!,
      floatingShadow: BoxShadow.lerpList(
        floatingShadow,
        other.floatingShadow,
        t,
      )!,
    );
  }
}

extension NaviaThemeContext on BuildContext {
  /// The [NaviaSurfaces] of the closest theme.
  NaviaSurfaces get naviaSurfaces =>
      Theme.of(this).extension<NaviaSurfaces>() ?? NaviaSurfaces.light;
}
