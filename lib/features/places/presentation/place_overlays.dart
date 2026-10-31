import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/domain/map_overlays.dart';
import '../../navigation/presentation/navigation_controller.dart';
import 'place_discovery_controller.dart';
import 'place_marker_style.dart';

/// Discovered places to draw on the map, with the selected one highlighted.
final mapPlacesProvider = Provider<List<MapPlace>>((ref) {
  final (places, category) = ref.watch(
    placeDiscoveryProvider.select((s) => (s.places, s.category)),
  );
  if (category == null) return const [];
  final selectedKey = ref.watch(
    navigationControllerProvider.select((s) => s.selectedPlace?.ref.key),
  );
  return [
    for (final place in places)
      MapPlace(
        key: place.ref.key,
        point: place.point,
        imageId: category.markerImageId,
        color: category.markerColor,
        name: place.name,
        selected: place.ref.key == selectedKey,
      ),
  ];
});
