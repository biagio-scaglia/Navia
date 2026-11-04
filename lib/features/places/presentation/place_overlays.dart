import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../favorites/presentation/favorites_controller.dart';
import '../../map/domain/map_overlays.dart';
import '../../navigation/presentation/navigation_controller.dart';
import 'place_discovery_controller.dart';
import 'place_marker_style.dart';

/// Prefix of the [MapPlace.key] of a favorite drawn on the map.
const favoritePlaceKeyPrefix = 'favorite:';

/// Places to draw on the map: the discovered ones, with the selected one
/// highlighted, and the favorites, always visible as gold stars.
///
/// A discovered place that is also a favorite keeps its own key, so that a
/// tap still opens its details, but is drawn with the star.
final mapPlacesProvider = Provider<List<MapPlace>>((ref) {
  final (places, category) = ref.watch(
    placeDiscoveryProvider.select((s) => (s.places, s.category)),
  );
  final favorites = ref.watch(favoritesProvider);
  final selectedKey = ref.watch(
    navigationControllerProvider.select((s) => s.selectedPlace?.ref.key),
  );
  final discovered = category == null
      ? const <String>{}
      : {for (final place in places) place.ref.key};
  final favoriteKeys = {
    for (final favorite in favorites)
      if (favorite.osmRef case final ref?) ref.key,
  };
  return [
    if (category != null)
      for (final place in places)
        if (favoriteKeys.contains(place.ref.key))
          MapPlace(
            key: place.ref.key,
            point: place.point,
            imageId: FavoriteMarker.imageId,
            color: FavoriteMarker.color,
            name: place.name,
            selected: place.ref.key == selectedKey,
          )
        else
          MapPlace(
            key: place.ref.key,
            point: place.point,
            imageId: category.markerImageId,
            color: category.markerColor,
            name: place.name,
            selected: place.ref.key == selectedKey,
          ),
    for (final favorite in favorites)
      if (!discovered.contains(favorite.osmRef?.key))
        MapPlace(
          key: '$favoritePlaceKeyPrefix${favorite.id}',
          point: favorite.point,
          imageId: FavoriteMarker.imageId,
          color: FavoriteMarker.color,
          name: favorite.name,
        ),
  ];
});
