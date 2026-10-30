import 'package:flutter/material.dart';

import '../../../../app/theme/navia_surfaces.dart';
import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../domain/map_style_source.dart';

/// Always-visible map data credit, as required by the OpenStreetMap
/// attribution guidelines. Tapping it lists every notice with its link.
class MapAttributionChip extends StatelessWidget {
  const MapAttributionChip({super.key, required this.source});

  final MapStyleSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: AppStrings.mapAttribution,
      excludeSemantics: true,
      child: Material(
        color: context.naviaSurfaces.floating.withValues(alpha: 0.9),
        shape: StadiumBorder(
          side: BorderSide(color: context.naviaSurfaces.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showMapAttributionSheet(context, source),
          child: ConstrainedBox(
            // A compact credit keeps the map unobstructed; the same notices
            // are also listed in the settings screen.
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NaviaSpacing.md,
                vertical: NaviaSpacing.sm,
              ),
              child: Text(
                AppStrings.mapAttributionShort,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showMapAttributionSheet(
  BuildContext context,
  MapStyleSource source,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NaviaSpacing.xl,
              0,
              NaviaSpacing.xl,
              NaviaSpacing.sm,
            ),
            child: Text(
              AppStrings.mapAttribution,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          MapAttributionList(source: source),
          const SizedBox(height: NaviaSpacing.lg),
        ],
      ),
    ),
  );
}

/// The attribution notices of [source], each linking to its source.
class MapAttributionList extends StatelessWidget {
  const MapAttributionList({super.key, required this.source});

  final MapStyleSource source;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final attribution in source.attributions)
          ListTile(
            leading: const NaviaIcon(NaviaIcons.copyright),
            title: Text(attribution.label),
            subtitle: Text(Uri.parse(attribution.url).host),
            trailing: const NaviaIcon(NaviaIcons.externalLink, size: 20),
            onTap: () => openExternalLink(context, attribution.url),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NaviaSpacing.lg,
            vertical: NaviaSpacing.sm,
          ),
          child: Text(
            AppStrings.mapDataNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
