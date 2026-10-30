import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/domain/map_overlays.dart';
import '../../navigation/presentation/navigation_controller.dart';
import 'place_discovery_controller.dart';

/// Discovered places to draw on the map, with the selected one highlighted.
final mapPlacesProvider = Provider<List<MapPlace>>((ref) {
  final places = ref.watch(placeDiscoveryProvider.select((s) => s.places));
  final selectedKey = ref.watch(
    navigationControllerProvider.select((s) => s.selectedPlace?.ref.key),
  );
  return [
    for (final place in places)
      MapPlace(
        key: place.ref.key,
        point: place.point,
        name: place.name,
        selected: place.ref.key == selectedKey,
      ),
  ];
});
