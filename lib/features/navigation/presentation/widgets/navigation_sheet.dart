import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../core/widgets/floating_surface.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../../../core/widgets/navia_sheet.dart';
import '../../../favorites/presentation/favorites_controller.dart';
import '../../../search/data/photon_geocoding_repository.dart';
import '../../../search/presentation/search_screen.dart';
import '../../data/osrm_routing_repository.dart';
import '../../domain/navigation_models.dart';
import '../navigation_controller.dart';
import '../navigation_labels.dart';

/// Collapsible bottom panel for point selection and route planning.
///
/// It is laid out next to the map, not inside it, so expanding or collapsing
/// it never rebuilds the map view.
class NavigationSheet extends ConsumerStatefulWidget {
  const NavigationSheet({super.key});

  @override
  ConsumerState<NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends ConsumerState<NavigationSheet> {
  bool _expanded = true;

  NavigationController get _controller =>
      ref.read(navigationControllerProvider.notifier);

  bool get _searchAvailable => ref.read(geocodingRepositoryProvider) != null;

  /// Lets the user choose a waypoint through search.
  Future<Waypoint?> _pickWaypoint({required bool origin}) async {
    if (!_searchAvailable) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.searchLongPressTip)),
        );
      return null;
    }
    final pick = await SearchScreen.open(
      context,
      hint: origin
          ? AppStrings.searchOriginHint
          : AppStrings.searchDestinationHint,
      offerCurrentLocation: true,
    );
    return switch (pick) {
      null => null,
      CurrentLocationPick() => const CurrentLocationWaypoint(),
      PlacePick(:final place) => PointWaypoint(
        place.point,
        label: place.name,
        description: place.description,
      ),
    };
  }

  Future<void> _pickOrigin() async {
    final waypoint = await _pickWaypoint(origin: true);
    if (waypoint != null && mounted) _controller.setOrigin(waypoint);
  }

  Future<void> _pickDestination() async {
    final waypoint = await _pickWaypoint(origin: false);
    if (waypoint == null || !mounted) return;
    if (ref.read(navigationControllerProvider).origin == null) {
      _controller.setOrigin(const CurrentLocationWaypoint());
    }
    _controller.setDestination(waypoint);
  }

  Future<void> _startPlanning() async {
    setState(() => _expanded = true);
    if (_searchAvailable) {
      await _pickDestination();
    } else {
      _controller.setOrigin(const CurrentLocationWaypoint());
    }
  }

  void _setExpanded(bool expanded) {
    if (expanded != _expanded) setState(() => _expanded = expanded);
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(
      navigationControllerProvider.select((s) => s.selection),
    );
    final planning = ref.watch(
      navigationControllerProvider.select((s) => s.isPlanning),
    );
    final routingAvailable = ref
        .watch(routingRepositoryProvider)
        .supportedModes
        .isNotEmpty;

    final Widget? content;
    if (selection != null) {
      content = _SelectionCard(
        selection: selection,
        routingAvailable: routingAvailable,
        onUseAsOrigin: () {
          _setExpanded(true);
          _controller.useSelectionAsOrigin();
        },
        onUseAsDestination: () {
          _setExpanded(true);
          _controller.useSelectionAsDestination();
        },
        onClose: _controller.clearSelection,
      );
    } else if (planning) {
      content = _PlanningPanel(
        expanded: _expanded,
        onExpandedChanged: _setExpanded,
        onPickOrigin: _pickOrigin,
        onPickDestination: _pickDestination,
      );
    } else if (routingAvailable) {
      content = _WhereToButton(onPressed: _startPlanning);
    } else {
      content = null;
    }
    if (content == null) return const SizedBox.shrink();

    return FloatingSurface(
      child: AnimatedSize(
        duration: NaviaDurations.medium,
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: content,
      ),
    );
  }
}

class _WhereToButton extends StatelessWidget {
  const _WhereToButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NaviaSpacing.lg,
          vertical: NaviaSpacing.md,
        ),
        child: Row(
          children: [
            NaviaIcon(NaviaIcons.directions, color: theme.colorScheme.primary),
            const SizedBox(width: NaviaSpacing.md),
            Expanded(
              child: Text(
                AppStrings.whereTo,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              AppStrings.directions,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionCard extends ConsumerWidget {
  const _SelectionCard({
    required this.selection,
    required this.routingAvailable,
    required this.onUseAsOrigin,
    required this.onUseAsDestination,
    required this.onClose,
  });

  final PointWaypoint selection;
  final bool routingAvailable;
  final VoidCallback onUseAsOrigin;
  final VoidCallback onUseAsDestination;
  final VoidCallback onClose;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final favorites = ref.read(favoritesProvider.notifier);
    final existing = favorites.findNear(selection.point);
    if (existing != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppStrings.favoriteExists(existing.name))),
        );
      return;
    }
    final name = await showNameDialog(
      context,
      title: AppStrings.saveFavorite,
      label: AppStrings.favoriteName,
      initialValue: selection.label ?? AppStrings.favoriteDefaultName,
    );
    if (name == null) return;
    final result = await favorites.add(name, selection.point);
    if (result == FavoriteAddResult.added) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(AppStrings.favoriteSaved(name))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final lookup = ref.watch(
      navigationControllerProvider.select((s) => s.selectionLookup),
    );
    final saved = ref.watch(
      favoritesProvider.select(
        (favorites) => favorites.any(
          (f) =>
              f.point.distanceTo(selection.point) <=
              FavoritesController.duplicateRadiusMeters,
        ),
      ),
    );
    final category = selection.category;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NaviaSpacing.lg,
        NaviaSpacing.md,
        NaviaSpacing.xs,
        NaviaSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: NaviaSpacing.xs),
                child: NaviaIcon(
                  NaviaIcons.destination,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: NaviaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null)
                      Text(
                        category.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    Text(
                      selection.label ?? AppStrings.selectedPoint,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (selection.description case final description?)
                      Text(description, style: muted),
                    if (lookup == SelectionLookup.loading)
                      Semantics(
                        liveRegion: true,
                        child: Text(AppStrings.lookingUpAddress, style: muted),
                      ),
                    if (lookup == SelectionLookup.failed)
                      Text(AppStrings.addressUnavailable, style: muted),
                    const SizedBox(height: NaviaSpacing.xs),
                    SelectableText(
                      selection.point.toDisplayString(),
                      semanticsLabel:
                          '${AppStrings.coordinates}: '
                          '${selection.point.toDisplayString()}',
                      style: muted?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved
                    ? AppStrings.savedFavorite
                    : AppStrings.saveFavorite,
                onPressed: () => _save(context, ref),
                icon: NaviaIcon(
                  saved ? NaviaIcons.starFilled : NaviaIcons.star,
                  color: saved ? theme.colorScheme.primary : null,
                ),
              ),
              IconButton(
                tooltip: AppStrings.close,
                onPressed: onClose,
                icon: const NaviaIcon(NaviaIcons.close),
              ),
            ],
          ),
          if (routingAvailable) ...[
            const SizedBox(height: NaviaSpacing.md),
            Padding(
              padding: const EdgeInsets.only(right: NaviaSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onUseAsOrigin,
                      icon: const NaviaIcon(NaviaIcons.origin),
                      label: const Text(AppStrings.origin),
                    ),
                  ),
                  const SizedBox(width: NaviaSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onUseAsDestination,
                      icon: const NaviaIcon(NaviaIcons.destination),
                      label: const Text(AppStrings.destination),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanningPanel extends ConsumerWidget {
  const _PlanningPanel({
    required this.expanded,
    required this.onExpandedChanged,
    required this.onPickOrigin,
    required this.onPickDestination,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigationControllerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          expanded: expanded,
          onExpandedChanged: onExpandedChanged,
          onClose: controller.clear,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NaviaSpacing.md,
              0,
              NaviaSpacing.md,
              NaviaSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WaypointFields(
                  onPickOrigin: onPickOrigin,
                  onPickDestination: onPickDestination,
                ),
                const _ModeSelector(),
                const SizedBox(height: NaviaSpacing.md),
                const _RouteStatusArea(),
              ],
            ),
          ),
      ],
    );
  }
}

class _SheetHeader extends ConsumerWidget {
  const _SheetHeader({
    required this.expanded,
    required this.onExpandedChanged,
    required this.onClose,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (mode, route, destination) = ref.watch(
      navigationControllerProvider.select(
        (s) => (s.mode, s.route, s.destination),
      ),
    );
    final title = route != null
        ? '${formatDuration(route.duration)} · '
              '${formatDistance(route.distanceMeters)}'
        : destination?.title ?? AppStrings.chooseDestination;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 200) onExpandedChanged(velocity < 0);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: NaviaSpacing.sm),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: NaviaSpacing.lg),
              NaviaIcon(mode.icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: NaviaSpacing.sm),
              Expanded(
                child: Text(
                  expanded ? AppStrings.directions : title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: expanded
                    ? AppStrings.collapseSheet
                    : AppStrings.expandSheet,
                onPressed: () => onExpandedChanged(!expanded),
                icon: NaviaIcon(
                  expanded ? NaviaIcons.chevronDown : NaviaIcons.chevronUp,
                ),
              ),
              IconButton(
                tooltip: AppStrings.closeRoute,
                onPressed: onClose,
                icon: const NaviaIcon(NaviaIcons.close),
              ),
              const SizedBox(width: NaviaSpacing.xs),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaypointFields extends ConsumerWidget {
  const _WaypointFields({
    required this.onPickOrigin,
    required this.onPickDestination,
  });

  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final (origin, destination) = ref.watch(
      navigationControllerProvider.select((s) => (s.origin, s.destination)),
    );

    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: NaviaRadii.mdAll,
            ),
            child: Column(
              children: [
                _WaypointField(
                  label: AppStrings.origin,
                  placeholder: AppStrings.chooseOrigin,
                  waypoint: origin,
                  icon: NaviaIcons.origin,
                  iconColor: dark ? NaviaColors.aquaLight : NaviaColors.aqua,
                  onTap: onPickOrigin,
                ),
                const Divider(indent: 48),
                _WaypointField(
                  label: AppStrings.destination,
                  placeholder: AppStrings.chooseDestination,
                  waypoint: destination,
                  icon: NaviaIcons.destination,
                  iconColor: dark
                      ? NaviaColors.destinationDark
                      : NaviaColors.destination,
                  onTap: onPickDestination,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: AppStrings.swapWaypoints,
          onPressed: origin == null && destination == null
              ? null
              : ref.read(navigationControllerProvider.notifier).swap,
          icon: const NaviaIcon(NaviaIcons.swap),
        ),
      ],
    );
  }
}

class _WaypointField extends StatelessWidget {
  const _WaypointField({
    required this.label,
    required this.placeholder,
    required this.waypoint,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final String placeholder;
  final Waypoint? waypoint;
  final NaviaIcons icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waypoint = this.waypoint;
    return Semantics(
      button: true,
      label: '$label: ${waypoint?.title ?? placeholder}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: NaviaRadii.mdAll,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NaviaSpacing.md,
              vertical: NaviaSpacing.sm,
            ),
            child: Row(
              children: [
                NaviaIcon(icon, color: iconColor, size: 22),
                const SizedBox(width: NaviaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        waypoint?.title ?? placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: waypoint == null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSelector extends ConsumerWidget {
  const _ModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = ref.watch(routingRepositoryProvider).supportedModes;
    final mode = ref.watch(navigationControllerProvider.select((s) => s.mode));
    // A single mode needs no selector; its icon is shown in the header.
    if (modes.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: NaviaSpacing.md),
      child: SegmentedButton<TravelMode>(
        showSelectedIcon: false,
        segments: [
          for (final candidate in TravelMode.values)
            if (modes.contains(candidate))
              ButtonSegment(
                value: candidate,
                label: Text(candidate.label),
                icon: NaviaIcon(candidate.icon),
              ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => ref
            .read(navigationControllerProvider.notifier)
            .setMode(selection.single),
      ),
    );
  }
}

class _RouteStatusArea extends ConsumerWidget {
  const _RouteStatusArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(navigationControllerProvider.notifier);
    final (status, route, error, canCalculate) = ref.watch(
      navigationControllerProvider.select(
        (s) => (s.routeStatus, s.route, s.error, s.canCalculate),
      ),
    );

    return switch (status) {
      RouteStatus.idle => FilledButton.icon(
        onPressed: canCalculate ? controller.calculate : null,
        icon: const NaviaIcon(NaviaIcons.directions),
        label: const Text(AppStrings.calculateRoute),
      ),
      RouteStatus.loading => Semantics(
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: NaviaSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: NaviaSpacing.md),
              Text(AppStrings.calculatingRoute),
            ],
          ),
        ),
      ),
      RouteStatus.ready when route != null => _RouteSummary(route: route),
      _ => Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.routeUnavailable,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: NaviaSpacing.xs),
              Text(error.message, style: theme.textTheme.bodyMedium),
            ],
            if (error?.isRetryable ?? true) ...[
              const SizedBox(height: NaviaSpacing.md),
              OutlinedButton.icon(
                onPressed: canCalculate ? controller.calculate : null,
                icon: const NaviaIcon(NaviaIcons.refresh),
                label: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    };
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.route});

  final NavRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatDuration(route.duration),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: NaviaSpacing.md),
            Text(
              formatDistance(route.distanceMeters),
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            NaviaIcon(
              route.mode.icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: NaviaSpacing.xs),
            Text(route.mode.label, style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: NaviaSpacing.xs),
        Text(AppStrings.routeEstimateNote, style: muted),
        const SizedBox(height: NaviaSpacing.sm),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: NaviaSpacing.sm,
          children: [
            Text(AppStrings.routeAttribution, style: muted),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, NaviaSizes.minTouchTarget),
              ),
              onPressed: () =>
                  openExternalLink(context, AppConfig.fixTheMapUrl),
              child: const Text(AppStrings.reportMapIssue),
            ),
          ],
        ),
      ],
    );
  }
}
