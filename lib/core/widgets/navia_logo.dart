import 'package:flutter/material.dart';

import '../../app/theme/navia_tokens.dart';

/// The Navia mark: a navigation arrow on a glossy blue-to-aqua disc.
class NaviaLogoMark extends StatelessWidget {
  const NaviaLogoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [NaviaColors.brand, NaviaColors.aqua],
          ),
        ),
        foregroundDecoration: const BoxDecoration(
          shape: BoxShape.circle,
          // Soft top highlight, the only "aero" gloss in the mark.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
          ),
        ),
        child: Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

/// Logo mark followed by the "Navia" wordmark.
class NaviaWordmark extends StatelessWidget {
  const NaviaWordmark({super.key, this.markSize = 32});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NaviaLogoMark(size: markSize),
        const SizedBox(width: NaviaSpacing.sm),
        Text(
          'Navia',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
