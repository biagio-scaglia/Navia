import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_surfaces.dart';
import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/navia_icon.dart';
import 'transit_controller.dart';
import 'transit_stop_section.dart';

/// The AMTAB line shown on the map, with how many of its buses are running
/// and a button to hide it. It stays while the user taps around the map:
/// closing a stop card or tapping the line does not hide it.
class TransitLineBanner extends ConsumerWidget {
  const TransitLineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(transitLineProvider);
    final line = ref
        .watch(transitDataProvider)
        .value
        ?.routes
        .where((r) => r.index == route)
        .firstOrNull;
    if (route == null || line == null) return const SizedBox.shrink();
    final running = ref.watch(transitVehiclesProvider).length;
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: context.naviaSurfaces.floatingDecoration(
          borderRadius: NaviaRadii.pill,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NaviaSpacing.sm,
            NaviaSpacing.xs,
            NaviaSpacing.xs,
            NaviaSpacing.xs,
          ),
          child: Row(
            children: [
              TransitLineBadge(name: line.name, rgb: line.color),
              const SizedBox(width: NaviaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (line.longName.isNotEmpty)
                      Text(
                        line.longName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    Text(
                      AppStrings.busesRunning(running),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppStrings.hideLine,
                onPressed: ref.read(transitLineProvider.notifier).hide,
                icon: const NaviaIcon(NaviaIcons.close, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
