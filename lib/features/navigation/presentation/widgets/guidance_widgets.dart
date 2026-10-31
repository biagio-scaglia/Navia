import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/navia_surfaces.dart';
import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../domain/navigation_models.dart';
import '../guidance_controller.dart';
import '../navigation_controller.dart';
import '../route_instructions.dart';

/// Top banner during guidance: the next maneuver and its distance.
class GuidanceBanner extends ConsumerWidget {
  const GuidanceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(guidanceProvider);
    final controller = ref.read(guidanceProvider.notifier);
    final step = state.nextStep;
    final scheme = theme.colorScheme;
    final instruction = state.rerouting
        ? AppStrings.reroutingNow
        : step == null
        ? AppStrings.followRoute
        : RouteInstructions.text(step);

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: context.naviaSurfaces.primaryGradient,
          borderRadius: NaviaRadii.lgAll,
          boxShadow: context.naviaSurfaces.floatingShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NaviaSpacing.lg,
            NaviaSpacing.md,
            NaviaSpacing.sm,
            NaviaSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                _iconFor(step),
                color: Colors.white,
                size: 36,
                semanticLabel: '',
              ),
              const SizedBox(width: NaviaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!state.rerouting && step != null)
                      Text(
                        formatDistance(state.distanceToManeuver),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: state.muted
                    ? AppStrings.unmuteVoice
                    : AppStrings.muteVoice,
                onPressed: controller.toggleMuted,
                color: Colors.white,
                icon: Icon(
                  state.muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Material arrows read better than text for maneuvers at a glance.
  static IconData _iconFor(RouteStep? step) {
    if (step == null) return Icons.navigation_rounded;
    if (step.kind == ManeuverKind.arrive) return Icons.flag_rounded;
    if (step.kind == ManeuverKind.roundabout) {
      return Icons.roundabout_right_rounded;
    }
    return switch (step.direction) {
      ManeuverDirection.uturn => Icons.u_turn_left_rounded,
      ManeuverDirection.sharpRight ||
      ManeuverDirection.right => Icons.turn_right_rounded,
      ManeuverDirection.slightRight => Icons.turn_slight_right_rounded,
      ManeuverDirection.slightLeft => Icons.turn_slight_left_rounded,
      ManeuverDirection.sharpLeft ||
      ManeuverDirection.left => Icons.turn_left_rounded,
      ManeuverDirection.straight || null => Icons.straight_rounded,
    };
  }
}

/// Bottom panel during guidance: what is left and how to stop.
class GuidancePanel extends ConsumerWidget {
  const GuidancePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remaining = ref.watch(
      guidanceProvider.select((s) => s.remainingMeters),
    );
    final route = ref.watch(
      navigationControllerProvider.select((s) => s.route),
    );
    final eta = route == null || route.distanceMeters == 0
        ? null
        : DateTime.now().add(
            route.duration * (remaining / route.distanceMeters),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NaviaSpacing.lg,
        NaviaSpacing.md,
        NaviaSpacing.lg,
        NaviaSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eta != null)
                  Text(
                    AppStrings.arrivalAt(formatClockTime(eta)),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                Text(
                  AppStrings.remaining(formatDistance(remaining)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () =>
                unawaited(ref.read(guidanceProvider.notifier).stop()),
            icon: const NaviaIcon(NaviaIcons.close, size: 20),
            label: const Text(AppStrings.stopGuidance),
          ),
        ],
      ),
    );
  }
}

/// The maneuvers of [route], as an expandable list.
class RouteStepList extends StatelessWidget {
  const RouteStepList({super.key, required this.route});

  final NavRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = route.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          AppStrings.routeSteps(steps.length),
          style: theme.textTheme.titleSmall,
        ),
        children: [
          for (final step in steps)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                GuidanceBanner._iconFor(step),
                color: theme.colorScheme.primary,
              ),
              title: Text(RouteInstructions.text(step)),
              trailing: step.distanceMeters > 0
                  ? Text(
                      formatDistance(step.distanceMeters),
                      style: theme.textTheme.labelMedium,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
