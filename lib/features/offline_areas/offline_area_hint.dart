import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../app/theme/navia_surfaces.dart';
import '../../app/theme/navia_tokens.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/navia_icon.dart';
import '../../shared/models/geo_point.dart';
import '../../shared/providers/shared_preferences_provider.dart';
import '../offline_maps/data/map_data_client.dart';
import '../offline_maps/presentation/offline_maps_controller.dart';
import '../places/data/place_data_client.dart';
import '../places/presentation/offline_places_controller.dart';
import 'offline_areas_screen.dart';

/// Which half of a downloaded zone is missing.
enum OfflineAreaGap { map, places }

/// A zone shown on the map whose places are on the device but not its map,
/// or the opposite: the two downloads are easily confused.
@immutable
class OfflineAreaHint {
  const OfflineAreaHint({
    required this.regionId,
    required this.regionName,
    required this.gap,
  });

  final String regionId;
  final String regionName;
  final OfflineAreaGap gap;

  String get _dismissKey => '${gap.name}:$regionId';

  @override
  bool operator ==(Object other) =>
      other is OfflineAreaHint &&
      other.regionId == regionId &&
      other.regionName == regionName &&
      other.gap == gap;

  @override
  int get hashCode => Object.hash(regionId, regionName, gap);
}

/// The hint for the area at the map center, if any. Only stored data is
/// compared: nothing is requested from the network.
///
/// A dismissed hint is remembered on the device, so that someone who wants
/// only one of the two downloads is not asked again.
class OfflineAreaHintController extends Notifier<OfflineAreaHint?> {
  static const _dismissedKey = 'offline_hint.dismissed';

  GeoPoint _center = AppConfig.initialCamera.target;

  @override
  OfflineAreaHint? build() {
    ref
      ..watch(installedMapRegionsProvider)
      ..watch(installedRegionsProvider);
    return _compute();
  }

  void centerChanged(GeoPoint center) {
    _center = center;
    final hint = _compute();
    if (hint != state) state = hint;
  }

  Future<void> dismiss() async {
    final hint = state;
    if (hint == null) return;
    final preferences = ref.read(sharedPreferencesProvider);
    await preferences.setStringList(_dismissedKey, [
      ...?preferences.getStringList(_dismissedKey),
      hint._dismissKey,
    ]);
    if (ref.mounted) state = null;
  }

  OfflineAreaHint? _compute() {
    // A download that cannot be offered is not worth a hint.
    if (ref.read(mapDataClientProvider) == null ||
        ref.read(placeDataClientProvider) == null) {
      return null;
    }
    final maps = ref.read(installedMapRegionsProvider);
    final places = ref.read(installedRegionsProvider);
    final mapHere = maps
        .where((r) => r.region.bounds.containsPoint(_center))
        .firstOrNull;
    final placesHere = places
        .where((r) => r.region.bounds.containsPoint(_center))
        .firstOrNull;
    final OfflineAreaHint hint;
    if (placesHere != null && mapHere == null) {
      hint = OfflineAreaHint(
        regionId: placesHere.region.id,
        regionName: placesHere.region.name,
        gap: OfflineAreaGap.map,
      );
    } else if (mapHere != null && placesHere == null) {
      hint = OfflineAreaHint(
        regionId: mapHere.region.id,
        regionName: mapHere.region.name,
        gap: OfflineAreaGap.places,
      );
    } else {
      return null;
    }
    final dismissed = ref
        .read(sharedPreferencesProvider)
        .getStringList(_dismissedKey);
    return (dismissed ?? const []).contains(hint._dismissKey) ? null : hint;
  }
}

final offlineAreaHintProvider =
    NotifierProvider<OfflineAreaHintController, OfflineAreaHint?>(
      OfflineAreaHintController.new,
    );

/// Banner over the map that points out the missing half of a zone.
class OfflineAreaHintBanner extends ConsumerWidget {
  const OfflineAreaHintBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = ref.watch(offlineAreaHintProvider);
    if (hint == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final text = switch (hint.gap) {
      OfflineAreaGap.map => AppStrings.hintMissingMap(hint.regionName),
      OfflineAreaGap.places => AppStrings.hintMissingPlaces(hint.regionName),
    };

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: context.naviaSurfaces.floatingDecoration(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NaviaSpacing.lg,
            NaviaSpacing.sm,
            NaviaSpacing.xs,
            NaviaSpacing.sm,
          ),
          child: Row(
            children: [
              NaviaIcon(
                NaviaIcons.cloudOff,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: NaviaSpacing.md),
              Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
              TextButton(
                onPressed: () => OfflineAreasScreen.open(context),
                child: const Text(AppStrings.download),
              ),
              IconButton(
                tooltip: AppStrings.hintDismiss,
                onPressed: ref.read(offlineAreaHintProvider.notifier).dismiss,
                icon: const NaviaIcon(NaviaIcons.close, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
