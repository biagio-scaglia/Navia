import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/navia_surfaces.dart';
import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../core/widgets/navia_buttons.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../../../core/widgets/navia_sheet.dart';
import '../../../favorites/domain/favorite.dart';
import '../../../favorites/presentation/favorites_controller.dart';
import '../../../places/presentation/widgets/place_article.dart';
import '../../../places/presentation/widgets/place_details.dart';
import '../../../search/data/photon_geocoding_repository.dart';
import '../../../search/presentation/search_screen.dart';
import '../../data/osrm_routing_repository.dart';
import '../../domain/navigation_models.dart';
import '../navigation_controller.dart';
import '../navigation_labels.dart';

/// Panel docked to the bottom of the map: where-to entry, the selected
/// place, and route planning.
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
        category: place.category,
      ),
    };
  }

  Future<void> _pickOrigin() async {
    final waypoint = await _pickWaypoint(origin: true);
    if (waypoint == null || !mounted) return;
    _controller.setOrigin(waypoint);
    await _controller.calculate();
  }

  Future<void> _pickDestination() async {
    final waypoint = await _pickWaypoint(origin: false);
    if (waypoint == null || !mounted) return;
    _routeTo(waypoint);
  }

  /// Plans a route to [destination], from the user location unless an
  /// origin was already chosen.
  void _routeTo(Waypoint destination) {
    _setExpanded(true);
    if (ref.read(navigationControllerProvider).origin == null) {
      _controller.setOrigin(const CurrentLocationWaypoint());
    }
    _controller.setDestination(destination);
    unawaited(_controller.calculate());
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
        onStartHere: () {
          _setExpanded(true);
          unawaited(_controller.useSelectionAsOrigin());
        },
        onDirections: () {
          _setExpanded(true);
          unawaited(_controller.useSelectionAsDestination());
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
      content = _WhereToPanel(
        onSearch: _pickDestination,
        onFavorite: (favorite) =>
            _routeTo(PointWaypoint(favorite.point, label: favorite.name)),
      );
    } else {
      content = null;
    }
    if (content == null) return const SizedBox.shrink();

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: context.naviaSurfaces.dockedDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSize(
          duration: NaviaDurations.medium,
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          // Scrolls when the parent caps the height (small or landscape
          // screens), so the panel never hides the whole map.
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [const _DragHandle(), content],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: NaviaSpacing.sm),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: NaviaRadii.pill,
          ),
        ),
      ),
    );
  }
}

/// Idle state: a large where-to field and quick routes to favorites.
class _WhereToPanel extends ConsumerWidget {
  const _WhereToPanel({required this.onSearch, required this.onFavorite});

  final VoidCallback onSearch;
  final ValueChanged<Favorite> onFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorites = ref.watch(favoritesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NaviaSpacing.lg,
        NaviaSpacing.md,
        NaviaSpacing.lg,
        NaviaSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: AppStrings.whereTo,
            excludeSemantics: true,
            child: Material(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSearch,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: NaviaSpacing.sm),
                      const NaviaIconBadge(NaviaIcons.directions),
                      const SizedBox(width: NaviaSpacing.md),
                      Expanded(
                        child: Text(
                          AppStrings.whereTo,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      NaviaIcon(
                        NaviaIcons.search,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: NaviaSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (favorites.isNotEmpty) ...[
            const SizedBox(height: NaviaSpacing.md),
            SizedBox(
              height: NaviaSizes.minTouchTarget,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: NaviaSpacing.sm),
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  return ActionChip(
                    avatar: NaviaIcon(
                      NaviaIcons.starFilled,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(favorite.name),
                    tooltip: '${AppStrings.directions}: ${favorite.name}',
                    onPressed: () => onFavorite(favorite),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionCard extends ConsumerWidget {
  const _SelectionCard({
    required this.selection,
    required this.routingAvailable,
    required this.onStartHere,
    required this.onDirections,
    required this.onClose,
  });

  final PointWaypoint selection;
  final bool routingAvailable;
  final VoidCallback onStartHere;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final favorites = ref.read(favoritesProvider.notifier);
    final place = ref.read(navigationControllerProvider).selectedPlace;
    final existing = favorites.findExisting(
      selection.point,
      osmRef: place?.ref,
    );
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
    final result = await favorites.add(
      name,
      selection.point,
      osmRef: place?.ref,
      category: place?.category ?? selection.category,
      address: selection.description,
    );
    if (result == FavoriteAddResult.added) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(AppStrings.favoriteSaved(name))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final lookup = ref.watch(
      navigationControllerProvider.select((s) => s.selectionLookup),
    );
    final place = ref.watch(
      navigationControllerProvider.select((s) => s.selectedPlace),
    );
    final saved = ref.watch(
      favoritesProvider.select(
        (favorites) => favorites.any(
          (f) =>
              (place != null && f.osmRef == place.ref) ||
              f.point.distanceTo(selection.point) <=
                  FavoritesController.duplicateRadiusMeters,
        ),
      ),
    );
    final category = selection.category;
    final destinationColor = theme.brightness == Brightness.dark
        ? NaviaColors.destinationDark
        : NaviaColors.destination;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NaviaSpacing.lg,
        NaviaSpacing.md,
        NaviaSpacing.lg,
        NaviaSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NaviaIconBadge(NaviaIcons.destination, color: destinationColor),
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
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    Text(
                      selection.label ?? AppStrings.selectedPoint,
                      style: theme.textTheme.titleLarge,
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NaviaSpacing.sm),
              NaviaTonalIconButton(
                icon: saved ? NaviaIcons.starFilled : NaviaIcons.star,
                tooltip: saved
                    ? AppStrings.savedFavorite
                    : AppStrings.saveFavorite,
                selected: saved,
                onPressed: () => _save(context, ref),
              ),
              const SizedBox(width: NaviaSpacing.sm),
              NaviaTonalIconButton(
                icon: NaviaIcons.close,
                tooltip: AppStrings.close,
                onPressed: onClose,
              ),
            ],
          ),
          if (place != null) ...[
            PlaceArticleSection(place: place),
            const SizedBox(height: NaviaSpacing.sm),
            PlaceDetailsList(place: place),
          ],
          const SizedBox(height: NaviaSpacing.md),
          PlaceQuickActions(
            point: selection.point,
            name: selection.label,
            address: selection.description,
          ),
          if (routingAvailable) ...[
            const SizedBox(height: NaviaSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDirections,
                    icon: const NaviaIcon(NaviaIcons.directions, size: 20),
                    label: const Text(AppStrings.directions),
                  ),
                ),
                const SizedBox(width: NaviaSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NaviaSpacing.md,
                      ),
                    ),
                    onPressed: onStartHere,
                    icon: const NaviaIcon(NaviaIcons.origin, size: 20),
                    label: const Text(
                      AppStrings.startHere,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
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
        _PlanningHeader(
          expanded: expanded,
          onExpandedChanged: onExpandedChanged,
          onClose: controller.clear,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NaviaSpacing.lg,
              0,
              NaviaSpacing.lg,
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
                const SizedBox(height: NaviaSpacing.lg),
                const _RouteStatusArea(),
              ],
            ),
          ),
      ],
    );
  }
}

/// Title row of the planning panel. Collapsed, it summarizes the route.
class _PlanningHeader extends ConsumerWidget {
  const _PlanningHeader({
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
    final title = expanded
        ? AppStrings.directions
        : route != null
        ? '${formatDuration(route.duration)} · '
              '${formatDistance(route.distanceMeters)}'
        : destination?.title ?? AppStrings.chooseDestination;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 200) onExpandedChanged(velocity < 0);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NaviaSpacing.lg,
          NaviaSpacing.sm,
          NaviaSpacing.md,
          NaviaSpacing.md,
        ),
        child: Row(
          children: [
            NaviaIconBadge(mode.icon, size: 36),
            const SizedBox(width: NaviaSpacing.md),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            NaviaTonalIconButton(
              icon: expanded ? NaviaIcons.chevronDown : NaviaIcons.chevronUp,
              tooltip: expanded
                  ? AppStrings.collapseSheet
                  : AppStrings.expandSheet,
              onPressed: () => onExpandedChanged(!expanded),
            ),
            const SizedBox(width: NaviaSpacing.sm),
            NaviaTonalIconButton(
              icon: NaviaIcons.close,
              tooltip: AppStrings.closeRoute,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Origin and destination joined by a dotted line, with the swap action.
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: NaviaRadii.mdAll,
        border: Border.all(color: context.naviaSurfaces.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _WaypointField(
                  label: AppStrings.origin,
                  placeholder: AppStrings.chooseOrigin,
                  waypoint: origin,
                  icon: NaviaIcons.origin,
                  iconColor: dark ? NaviaColors.aquaLight : NaviaColors.aqua,
                  connector: _Connector.below,
                  onTap: onPickOrigin,
                ),
                _WaypointField(
                  label: AppStrings.destination,
                  placeholder: AppStrings.chooseDestination,
                  waypoint: destination,
                  icon: NaviaIcons.destination,
                  iconColor: dark
                      ? NaviaColors.destinationDark
                      : NaviaColors.destination,
                  connector: _Connector.above,
                  onTap: onPickDestination,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: NaviaSpacing.sm),
            child: NaviaTonalIconButton(
              icon: NaviaIcons.swap,
              tooltip: AppStrings.swapWaypoints,
              onPressed: origin == null && destination == null
                  ? null
                  : () => unawaited(
                      ref.read(navigationControllerProvider.notifier).swap(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which side of a waypoint icon the dotted route line continues on.
enum _Connector { above, below }

class _WaypointField extends StatelessWidget {
  const _WaypointField({
    required this.label,
    required this.placeholder,
    required this.waypoint,
    required this.icon,
    required this.iconColor,
    required this.connector,
    required this.onTap,
  });

  static const _height = 60.0;
  static const _iconColumn = 48.0;

  final String label;
  final String placeholder;
  final Waypoint? waypoint;
  final NaviaIcons icon;
  final Color iconColor;
  final _Connector connector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waypoint = this.waypoint;
    final dots = theme.colorScheme.outline.withValues(alpha: 0.6);

    return Semantics(
      button: true,
      label: '$label: ${waypoint?.title ?? placeholder}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: NaviaRadii.mdAll,
        onTap: onTap,
        child: SizedBox(
          height: _height,
          child: Row(
            children: [
              SizedBox(
                width: _iconColumn,
                height: _height,
                child: CustomPaint(
                  painter: _ConnectorPainter(connector, dots),
                  child: Center(
                    child: NaviaIcon(icon, color: iconColor, size: 22),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontWeight: waypoint == null
                            ? FontWeight.w400
                            : FontWeight.w600,
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
    );
  }
}

/// Draws the dotted segment that links the origin and destination icons.
class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter(this.connector, this.color);

  final _Connector connector;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final x = size.width / 2;
    final center = size.height / 2;
    const gap = 16.0;
    final (start, end) = switch (connector) {
      _Connector.below => (center + gap, size.height),
      _Connector.above => (0.0, center - gap),
    };
    for (var y = start + 2; y < end; y += 6) {
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      oldDelegate.connector != connector || oldDelegate.color != color;
}

/// Travel modes as equal-width pills.
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
      child: Row(
        children: [
          for (final candidate in TravelMode.values)
            if (modes.contains(candidate))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NaviaSpacing.xs / 2,
                  ),
                  child: _ModePill(
                    mode: candidate,
                    selected: candidate == mode,
                    onSelected: () => unawaited(
                      ref
                          .read(navigationControllerProvider.notifier)
                          .setMode(candidate),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.mode,
    required this.selected,
    required this.onSelected,
  });

  final TravelMode mode;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;

    return Semantics(
      selected: selected,
      button: true,
      label: mode.label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: NaviaDurations.fast,
        decoration: ShapeDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selected ? null : onSelected,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NaviaIcon(mode.icon, size: 20, color: foreground),
                  const SizedBox(width: NaviaSpacing.xs + 2),
                  Flexible(
                    child: Text(
                      mode.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: foreground),
                    ),
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
      RouteStatus.idle when canCalculate => FilledButton.icon(
        onPressed: controller.calculate,
        icon: const NaviaIcon(NaviaIcons.directions, size: 20),
        label: const Text(AppStrings.calculateRoute),
      ),
      RouteStatus.idle => Text(
        AppStrings.routeHint,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      RouteStatus.loading => Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ClipRRect(
              borderRadius: NaviaRadii.pill,
              child: LinearProgressIndicator(minHeight: 4),
            ),
            const SizedBox(height: NaviaSpacing.md),
            Text(
              AppStrings.calculatingRoute,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      RouteStatus.ready when route != null => _RouteSummary(route: route),
      _ => Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.08),
            borderRadius: NaviaRadii.mdAll,
          ),
          child: Padding(
            padding: const EdgeInsets.all(NaviaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.routeUnavailable,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: NaviaSpacing.xs),
                  Text(error.message, style: theme.textTheme.bodyMedium),
                ],
                if (error?.isRetryable ?? true) ...[
                  const SizedBox(height: NaviaSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: canCalculate ? controller.calculate : null,
                      icon: const NaviaIcon(NaviaIcons.refresh, size: 20),
                      label: const Text(AppStrings.retry),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    final arrival = DateTime.now().add(route.duration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatDuration(route.duration),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: NaviaSpacing.md),
            Text(
              formatDistance(route.distanceMeters),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          AppStrings.arrivalAt(formatClockTime(arrival)),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: NaviaSpacing.sm),
        Text(AppStrings.routeEstimateNote, style: muted),
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
