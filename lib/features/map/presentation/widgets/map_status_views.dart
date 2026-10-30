import 'package:flutter/material.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/floating_surface.dart';
import '../../../../core/widgets/navia_logo.dart';

/// Shown until the first map style has loaded.
class MapLoadingView extends StatelessWidget {
  const MapLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: AppStrings.mapLoading,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NaviaLogoMark(size: 64),
              const SizedBox(height: NaviaSpacing.xl),
              const SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
              const SizedBox(height: NaviaSpacing.md),
              ExcludeSemantics(
                child: Text(
                  AppStrings.mapLoading,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recoverable error shown when the map could not be loaded.
class MapErrorView extends StatelessWidget {
  const MapErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(NaviaSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FloatingSurface(
              padding: const EdgeInsets.all(NaviaSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: NaviaSpacing.lg),
                  Text(
                    AppStrings.mapErrorTitle,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: NaviaSpacing.sm),
                  Text(
                    AppStrings.mapErrorBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: NaviaSpacing.xl),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
