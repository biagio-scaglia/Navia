import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../core/widgets/navia_buttons.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../../../shared/models/geo_point.dart';
import '../../../discover/discover.dart';
import '../../../location/presentation/location_controller.dart';
import '../../../reach/reach.dart';
import '../../domain/navigation_models.dart';
import '../navigation_labels.dart';

/// The idle panel, split in tabs so that each tool keeps a clean screen:
/// where to go, what to discover nearby, and what is reachable in time.
class ExplorePanel extends StatefulWidget {
  const ExplorePanel({
    super.key,
    required this.goTab,
    required this.mapCenter,
    required this.onFocus,
  });

  /// Content of the "Vai" tab.
  final Widget goTab;

  /// The point at the center of the map, for searches "here".
  final Future<GeoPoint?> Function() mapCenter;

  /// Shows a discovered article on the map.
  final ValueChanged<NearbyArticle> onFocus;

  @override
  State<ExplorePanel> createState() => _ExplorePanelState();
}

enum _Tab { go, discover, reach }

class _ExplorePanelState extends State<ExplorePanel> {
  _Tab _tab = _Tab.go;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NaviaSpacing.lg,
            NaviaSpacing.md,
            NaviaSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              for (final (tab, icon, label) in [
                (_Tab.go, NaviaIcons.directions, AppStrings.tabGo),
                (_Tab.discover, NaviaIcons.flag, AppStrings.tabDiscover),
                (_Tab.reach, NaviaIcons.clock, AppStrings.tabReach),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _TabPill(
                      icon: icon,
                      label: label,
                      selected: _tab == tab,
                      onTap: () => setState(() => _tab = tab),
                    ),
                  ),
                ),
            ],
          ),
        ),
        switch (_tab) {
          _Tab.go => widget.goTab,
          _Tab.discover => _DiscoverTab(
            mapCenter: widget.mapCenter,
            onFocus: widget.onFocus,
          ),
          _Tab.reach => _ReachTab(mapCenter: widget.mapCenter),
        },
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final NaviaIcons icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NaviaIcon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
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

/// "Scopri qui intorno": Wikipedia articles near the map center.
class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab({required this.mapCenter, required this.onFocus});

  final Future<GeoPoint?> Function() mapCenter;
  final ValueChanged<NearbyArticle> onFocus;

  Future<void> _search(WidgetRef ref) async {
    final center = await mapCenter();
    if (center != null) {
      await ref.read(discoverProvider.notifier).search(center);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(discoverProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
          if (state.status == DiscoverStatus.idle)
            Padding(
              padding: const EdgeInsets.only(bottom: NaviaSpacing.md),
              child: Text(AppStrings.discoverIntro, style: muted),
            ),
          FilledButton.tonalIcon(
            onPressed: state.status == DiscoverStatus.loading
                ? null
                : () => unawaited(_search(ref)),
            icon: const NaviaIcon(NaviaIcons.search, size: 20),
            label: Text(
              state.status == DiscoverStatus.idle
                  ? AppStrings.discoverHere
                  : AppStrings.discoverAgain,
            ),
          ),
          if (state.status == DiscoverStatus.loading)
            const Padding(
              padding: EdgeInsets.all(NaviaSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.status == DiscoverStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: NaviaSpacing.md),
              child: Text(
                state.failure?.message ?? AppStrings.placesUnavailable,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (state.status == DiscoverStatus.ready && state.articles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: NaviaSpacing.md),
              child: Text(AppStrings.discoverEmpty, style: muted),
            ),
          for (final article in state.articles.take(15))
            _ArticleTile(article: article, onTap: () => onFocus(article)),
          if (state.articles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: NaviaSpacing.sm),
              child: Text(AppStrings.discoverAttribution, style: muted),
            ),
        ],
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});

  final NearbyArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = article.thumbnail;
    final details = [
      ?article.description,
      formatDistance(article.distanceMeters),
    ].join(' · ');
    return InkWell(
      borderRadius: NaviaRadii.mdAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NaviaSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: NaviaRadii.smAll,
              child: thumbnail == null
                  ? const NaviaIconBadge(NaviaIcons.flag, size: 56)
                  : Image.network(
                      thumbnail.toString(),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          const NaviaIconBadge(NaviaIcons.flag, size: 56),
                    ),
            ),
            const SizedBox(width: NaviaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: AppStrings.readOnWikipedia,
              onPressed: () =>
                  openExternalLink(context, article.url.toString()),
              icon: const NaviaIcon(NaviaIcons.externalLink, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Dove arrivo in 15 minuti": reachable areas around the user or the map
/// center.
class _ReachTab extends ConsumerWidget {
  const _ReachTab({required this.mapCenter});

  final Future<GeoPoint?> Function() mapCenter;

  Future<void> _show(WidgetRef ref) async {
    final position = ref.read(locationControllerProvider).position;
    final from = position?.point ?? await mapCenter();
    if (from != null) await ref.read(reachProvider.notifier).show(from);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(reachProvider);
    final controller = ref.read(reachProvider.notifier);
    final located = ref.watch(
      locationControllerProvider.select((s) => s.position != null),
    );
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
          Text(AppStrings.reachIntro, style: muted),
          const SizedBox(height: NaviaSpacing.md),
          Wrap(
            spacing: NaviaSpacing.sm,
            children: [
              for (final mode in TravelMode.values)
                ChoiceChip(
                  avatar: NaviaIcon(mode.icon, size: 18),
                  label: Text(mode.label),
                  selected: state.mode == mode,
                  showCheckmark: false,
                  onSelected: (_) {
                    controller.setMode(mode);
                    if (state.status == ReachStatus.ready) {
                      unawaited(_show(ref));
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: NaviaSpacing.sm),
          Text(
            located ? AppStrings.reachFromYou : AppStrings.reachFromCenter,
            style: muted,
          ),
          const SizedBox(height: NaviaSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.status == ReachStatus.loading
                      ? null
                      : () => unawaited(_show(ref)),
                  icon: const NaviaIcon(NaviaIcons.clock, size: 20),
                  label: Text(
                    state.status == ReachStatus.ready
                        ? AppStrings.reachUpdate
                        : AppStrings.reachShow,
                  ),
                ),
              ),
              if (state.status == ReachStatus.ready) ...[
                const SizedBox(width: NaviaSpacing.sm),
                OutlinedButton(
                  onPressed: controller.hide,
                  child: const Text(AppStrings.reachHide),
                ),
              ],
            ],
          ),
          if (state.status == ReachStatus.loading)
            const Padding(
              padding: EdgeInsets.only(top: NaviaSpacing.md),
              child: LinearProgressIndicator(),
            ),
          if (state.status == ReachStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: NaviaSpacing.md),
              child: Text(
                state.failure?.message ?? AppStrings.placesUnavailable,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (state.status == ReachStatus.ready) ...[
            const SizedBox(height: NaviaSpacing.md),
            Row(
              children: [
                for (final (index, minutes) in ReachRepository.minutes.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: NaviaSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.16 * (3 - index),
                            ),
                            borderRadius: NaviaRadii.pill,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('$minutes min', style: muted),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NaviaSpacing.sm),
            Text(AppStrings.reachAttribution, style: muted),
          ],
        ],
      ),
    );
  }
}
