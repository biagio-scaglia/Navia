import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/open_link.dart';
import '../../../core/widgets/navia_icon.dart';
import '../../../shared/models/geo_point.dart';
import '../../places/presentation/place_marker_style.dart';
import '../data/transit_store.dart';
import '../domain/schedule.dart';
import '../domain/transit.dart';
import 'transit_controller.dart';
import 'transit_screen.dart';

/// Next AMTAB buses at the stop at [point], with its lines, which can be
/// shown on the map with their buses. Draws nothing away from a stop.
class TransitStopSection extends ConsumerStatefulWidget {
  const TransitStopSection({super.key, required this.point, this.category});

  final GeoPoint point;

  /// Category of the selection, which tells a bus stop before timetables
  /// are downloaded.
  final String? category;

  @override
  ConsumerState<TransitStopSection> createState() => _TransitStopSectionState();
}

class _TransitStopSectionState extends ConsumerState<TransitStopSection> {
  /// Keeps "in 4 min" current while the card stays open.
  Timer? _clock;

  /// Bari and its surroundings, where offering AMTAB's timetables makes
  /// sense before they are downloaded.
  static bool _inBari(GeoPoint p) =>
      p.latitude > 40.95 &&
      p.latitude < 41.25 &&
      p.longitude > 16.55 &&
      p.longitude < 17.05;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(transitStoreProvider) == null) return const SizedBox.shrink();
    final info = ref.watch(transitProvider.select((s) => s.info));
    final downloading = ref.watch(transitProvider.select((s) => s.downloading));
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (info == null) {
      final busStop =
          widget.category == AppStrings.amtabStop ||
          (widget.category?.startsWith('Fermata autobus') ?? false);
      if (!busStop || !_inBari(widget.point)) return const SizedBox.shrink();
      return _Box(
        children: [
          Row(
            children: [
              Expanded(child: Text(AppStrings.amtabMissing, style: muted)),
              const SizedBox(width: NaviaSpacing.sm),
              if (downloading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.tonal(
                  onPressed: () => confirmTransitDownload(context, ref),
                  child: const Text(AppStrings.amtabDownloadShort),
                ),
            ],
          ),
        ],
      );
    }

    final data = ref.watch(transitDataProvider).value;
    final stop = data?.stopNear(widget.point);
    if (data == null || stop == null) return const SizedBox.shrink();
    final raw = ref.watch(stopDeparturesProvider(stop.index)).value;
    final now = DateTime.now();
    final departures = raw == null
        ? const <Departure>[]
        : TransitSchedule.departures(
            raw,
            services: data.services,
            routes: data.routes,
            now: now,
          );
    final next = raw == null || departures.isNotEmpty
        ? null
        : TransitSchedule.next(
            raw,
            services: data.services,
            routes: data.routes,
            now: now,
          );
    final lines = data.routesAt(stop);
    final shownLine = ref.watch(transitLineProvider);
    final shown = lines.where((r) => r.index == shownLine).firstOrNull;

    return _Box(
      children: [
        Text(
          '${AppStrings.nextBuses} · ${stop.name.toUpperCase()}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: NaviaSpacing.xs),
        if (info.expiredOn(now))
          Text(
            AppStrings.amtabExpired(formatShortDate(info.validUntil)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        if (raw != null && departures.isEmpty)
          Text(
            next == null
                ? AppStrings.noBusService
                : '${AppStrings.noBusSoon} '
                      '${AppStrings.nextBusLater(next.route, formatClockTime(next.time))}',
            style: theme.textTheme.bodyMedium,
          ),
        for (final departure in departures)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                TransitLineBadge(name: departure.route, rgb: departure.color),
                const SizedBox(width: NaviaSpacing.sm),
                Expanded(
                  child: Text(
                    departure.headsign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: NaviaSpacing.sm),
                Text(
                  _when(departure.time, now),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: NaviaSpacing.sm),
          Text(AppStrings.busLines, style: muted),
          const SizedBox(height: NaviaSpacing.xs),
          Wrap(
            spacing: NaviaSpacing.xs,
            runSpacing: NaviaSpacing.xs,
            children: [
              for (final line in lines)
                TransitLineBadge(
                  name: line.name,
                  rgb: line.color,
                  selected: line.index == shownLine,
                  tooltip: AppStrings.showLine(line.name),
                  onTap: () {
                    final notifier = ref.read(transitLineProvider.notifier);
                    line.index == shownLine
                        ? notifier.hide()
                        : notifier.show(line.index);
                  },
                ),
            ],
          ),
        ],
        if (shown != null) ...[
          const SizedBox(height: NaviaSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(AppStrings.lineShown(shown.name), style: muted),
              ),
              TextButton(
                onPressed: ref.read(transitLineProvider.notifier).hide,
                child: const Text(AppStrings.hideLine),
              ),
            ],
          ),
        ],
        const SizedBox(height: NaviaSpacing.xs),
        Text(AppStrings.amtabSource, style: muted),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => openExternalLink(context, AppConfig.amtabWebsite),
            icon: const NaviaIcon(NaviaIcons.externalLink, size: 18),
            label: const Text(AppStrings.allTimetables),
          ),
        ),
      ],
    );
  }

  static String _when(DateTime time, DateTime now) {
    final minutes = time.difference(now).inMinutes;
    return minutes < 60 ? AppStrings.inMinutes(minutes) : formatClockTime(time);
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: NaviaSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: NaviaRadii.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(NaviaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A line number on its color, as on the bus stop poles.
class TransitLineBadge extends StatelessWidget {
  const TransitLineBadge({
    super.key,
    required this.name,
    required this.rgb,
    this.selected = false,
    this.tooltip,
    this.onTap,
  });

  final String name;
  final int? rgb;
  final bool selected;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = TransitMarker.lineColor(rgb);
    final onColor = color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final badge = Container(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: NaviaSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected || onTap == null
            ? color
            : color.withValues(alpha: 0.16),
        borderRadius: NaviaRadii.smAll,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: selected || onTap == null ? onColor : null,
        ),
      ),
    );
    if (onTap == null) return badge;
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: Tooltip(
        message: tooltip ?? name,
        child: InkWell(
          borderRadius: NaviaRadii.smAll,
          onTap: onTap,
          // A 28 px badge in a 48 px touch target.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: badge,
          ),
        ),
      ),
    );
  }
}
