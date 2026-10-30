import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/platform/system_share.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../../../shared/models/geo_point.dart';
import '../../domain/opening_hours.dart';
import '../../domain/place_links.dart';
import '../../domain/poi.dart';

/// The details OpenStreetMap has about [place], one row per available tag.
/// Missing tags produce no row.
class PlaceDetailsList extends StatelessWidget {
  const PlaceDetailsList({super.key, required this.place, this.now});

  final Poi place;

  /// The current instant, for the opening status; defaults to now.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final hours = place.openingHours;
    final cuisine = place.cuisine;
    final wheelchair = place.wheelchair;
    final phone = place.phone;
    final website = place.website;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hours != null)
          _DetailRow(
            icon: NaviaIcons.clock,
            label: AppStrings.openingHours,
            value: hours,
            badge: _OpeningBadge(
              status: OpeningHours.tryParse(
                hours,
              )?.statusNear(place.point, now ?? DateTime.now()),
            ),
          ),
        if (cuisine != null)
          _DetailRow(
            icon: NaviaIcons.restaurant,
            label: AppStrings.cuisine,
            value: cuisine,
          ),
        if (wheelchair != null)
          _DetailRow(
            icon: NaviaIcons.accessible,
            label: AppStrings.accessibility,
            value: switch (wheelchair) {
              WheelchairAccess.yes => AppStrings.wheelchairYes,
              WheelchairAccess.limited => AppStrings.wheelchairLimited,
              WheelchairAccess.no => AppStrings.wheelchairNo,
            },
          ),
        if (phone != null)
          _DetailRow(
            icon: NaviaIcons.phone,
            label: AppStrings.phone,
            value: phone,
            actionLabel: AppStrings.call,
            onTap: () => openExternalLink(
              context,
              PlaceLinks.phoneUri(phone).toString(),
            ),
          ),
        if (website != null)
          _DetailRow(
            icon: NaviaIcons.globe,
            label: AppStrings.website,
            value: website.host,
            actionLabel: AppStrings.openWebsite,
            onTap: () => openExternalLink(context, website.toString()),
          ),
        _DetailRow(
          icon: NaviaIcons.copyright,
          label: AppStrings.placeDataSource,
          value: AppStrings.viewOnOpenStreetMap,
          actionLabel: AppStrings.viewOnOpenStreetMap,
          onTap: () => openExternalLink(context, place.ref.url.toString()),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
    this.actionLabel,
    this.onTap,
  });

  final NaviaIcons icon;
  final String label;
  final String value;
  final Widget? badge;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactive = onTap != null;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: NaviaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: NaviaSizes.iconBadge,
            child: Center(
              child: NaviaIcon(
                icon,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: NaviaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (badge case final badge?) ...[
                      const SizedBox(width: NaviaSpacing.sm),
                      badge,
                    ],
                  ],
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: interactive ? theme.colorScheme.primary : null,
                    fontWeight: interactive ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
          if (interactive)
            Padding(
              padding: const EdgeInsets.only(top: NaviaSpacing.sm),
              child: NaviaIcon(
                NaviaIcons.externalLink,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
    if (!interactive) {
      return Semantics(
        label: '$label: $value',
        child: ExcludeSemantics(child: content),
      );
    }
    return Semantics(
      button: true,
      label: '${actionLabel ?? label}: $value',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: NaviaRadii.smAll,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: NaviaSizes.minTouchTarget,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// "Aperto ora" or "Chiuso ora", shown only when the status was computed.
class _OpeningBadge extends StatelessWidget {
  const _OpeningBadge({required this.status});

  final OpeningStatus? status;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    if (status == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final open = status == OpeningStatus.open;
    final color = open
        ? (theme.brightness == Brightness.dark
              ? NaviaColors.aquaLight
              : const Color(0xFF00806F))
        : theme.colorScheme.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: NaviaRadii.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          open ? AppStrings.openNow : AppStrings.closedNow,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Share and copy actions available for any selected point.
class PlaceQuickActions extends StatelessWidget {
  const PlaceQuickActions({
    super.key,
    required this.point,
    this.name,
    this.address,
  });

  final GeoPoint point;
  final String? name;
  final String? address;

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final shared = await SystemShare.shareText(
      PlaceLinks.shareText(point: point, name: name, address: address),
      subject: name,
    );
    if (!shared) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(AppStrings.shareFailed)));
    }
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: point.toDisplayString()));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(AppStrings.coordinatesCopied)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: NaviaSpacing.sm,
      runSpacing: NaviaSpacing.sm,
      children: [
        ActionChip(
          avatar: const NaviaIcon(NaviaIcons.share, size: 18),
          label: const Text(AppStrings.share),
          onPressed: () => _share(context),
        ),
        ActionChip(
          avatar: const NaviaIcon(NaviaIcons.copy, size: 18),
          label: const Text(AppStrings.copyCoordinates),
          onPressed: () => _copy(context),
        ),
      ],
    );
  }
}
