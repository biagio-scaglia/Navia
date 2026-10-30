import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/navia_surfaces.dart';
import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../data/overpass_places_repository.dart';
import '../../domain/poi_category.dart';
import '../place_discovery_controller.dart';

extension PoiCategoryIcon on PoiCategory {
  NaviaIcons get icon => switch (this) {
    PoiCategory.restaurants => NaviaIcons.restaurant,
    PoiCategory.cafes => NaviaIcons.cafe,
    PoiCategory.supermarkets => NaviaIcons.cart,
    PoiCategory.pharmacies => NaviaIcons.pharmacy,
    PoiCategory.hospitals => NaviaIcons.hospital,
    PoiCategory.museums => NaviaIcons.museum,
    PoiCategory.attractions => NaviaIcons.flag,
    PoiCategory.parks => NaviaIcons.tree,
    PoiCategory.hotels => NaviaIcons.bed,
    PoiCategory.transport => NaviaIcons.bus,
    PoiCategory.parking => NaviaIcons.parking,
    PoiCategory.fuel => NaviaIcons.fuel,
    PoiCategory.atms => NaviaIcons.cash,
  };
}

/// Horizontally scrollable category filters for place discovery, with the
/// state of the current search below them.
class PlaceCategoryBar extends ConsumerWidget {
  const PlaceCategoryBar({super.key, required this.padding});

  /// Horizontal insets of the first and last chip, so the list can scroll
  /// edge to edge.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(placesRepositoryProvider) == null) {
      return const SizedBox.shrink();
    }
    final selected = ref.watch(
      placeDiscoveryProvider.select((s) => s.category),
    );
    final controller = ref.read(placeDiscoveryProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: PoiCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: NaviaSpacing.sm),
            itemBuilder: (context, index) {
              final category = PoiCategory.values[index];
              return _CategoryChip(
                category: category,
                selected: category == selected,
                onPressed: () => controller.toggle(category),
              );
            },
          ),
        ),
        if (selected != null)
          Padding(
            padding: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
              top: NaviaSpacing.sm,
            ),
            child: const _DiscoveryStatus(),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onPressed,
  });

  final PoiCategory category;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = context.naviaSurfaces;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${category.label}, ${AppStrings.clearFilter}'
          : category.label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: selected ? scheme.primary : surfaces.floating,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? scheme.primary : surfaces.hairline,
            ),
          ),
          shadows: NaviaElevation.low,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NaviaSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NaviaIcon(
                    category.icon,
                    size: 18,
                    color: selected ? foreground : scheme.primary,
                  ),
                  const SizedBox(width: NaviaSpacing.xs + 2),
                  Text(
                    category.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: NaviaSpacing.xs),
                    NaviaIcon(NaviaIcons.close, size: 16, color: foreground),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact pill that explains what discovery is doing.
class _DiscoveryStatus extends ConsumerWidget {
  const _DiscoveryStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(placeDiscoveryProvider);
    final category = state.category;
    if (category == null) return const SizedBox.shrink();
    final controller = ref.read(placeDiscoveryProvider.notifier);

    final (String text, bool busy, bool retry) = switch (state.status) {
      DiscoveryStatus.idle => ('', false, false),
      DiscoveryStatus.loading => (AppStrings.placesLoading, true, false),
      DiscoveryStatus.zoomIn => (AppStrings.placesZoomIn, false, false),
      DiscoveryStatus.ready when state.places.isEmpty => (
        AppStrings.placesEmpty(category.label),
        false,
        false,
      ),
      DiscoveryStatus.ready => (
        AppStrings.placesFound(state.places.length),
        false,
        false,
      ),
      DiscoveryStatus.failed => (
        state.failure?.message ?? AppStrings.placesUnavailable,
        false,
        state.failure?.isRetryable ?? true,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: context.naviaSurfaces.floatingDecoration(
          borderRadius: NaviaRadii.pill,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            NaviaSpacing.md,
            retry ? 0 : NaviaSpacing.sm,
            retry ? 0 : NaviaSpacing.md,
            retry ? 0 : NaviaSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: NaviaSpacing.sm),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (retry)
                TextButton(
                  onPressed: controller.retry,
                  child: const Text(AppStrings.retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
