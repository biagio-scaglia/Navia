import 'package:flutter/material.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/floating_surface.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../../../core/widgets/navia_logo.dart';

/// Compact floating search bar with the Navia mark and settings access.
///
/// When search is not configured, the bar shows the wordmark instead of a
/// search field that would not work.
class MapTopBar extends StatelessWidget {
  const MapTopBar({
    super.key,
    required this.onOpenSettings,
    required this.onOpenFavorites,
    required this.onSearch,
  });

  static const height = 56.0;

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenFavorites;

  /// Opens search; null when search is unavailable.
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSearch = this.onSearch;

    return FloatingSurface(
      borderRadius: const BorderRadius.all(Radius.circular(height / 2)),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: onSearch == null
                  ? Padding(
                      padding: const EdgeInsets.only(left: NaviaSpacing.md),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          header: true,
                          child: const NaviaWordmark(markSize: 30),
                        ),
                      ),
                    )
                  : Semantics(
                      button: true,
                      label: AppStrings.searchHint,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: onSearch,
                        child: Padding(
                          padding: const EdgeInsets.only(left: NaviaSpacing.md),
                          child: Row(
                            children: [
                              const NaviaLogoMark(size: 30),
                              const SizedBox(width: NaviaSpacing.md),
                              Expanded(
                                child: Text(
                                  AppStrings.searchHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            IconButton(
              tooltip: AppStrings.favorites,
              onPressed: onOpenFavorites,
              icon: const NaviaIcon(NaviaIcons.star),
            ),
            Padding(
              padding: const EdgeInsets.only(right: NaviaSpacing.xs),
              child: IconButton(
                tooltip: AppStrings.settings,
                onPressed: onOpenSettings,
                icon: const NaviaIcon(NaviaIcons.settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
