import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../favorites/presentation/favorites_controller.dart';
import '../../map/domain/map_overlays.dart';
import '../../map/presentation/map_providers.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../transit/domain/transit.dart';
import '../../transit/presentation/transit_controller.dart';
import 'place_discovery_controller.dart';
import 'place_marker_style.dart';

/// Prefix of the [MapPlace.key] of a favorite drawn on the map.
const favoritePlaceKeyPrefix = 'favorite:';

/// Prefix of the [MapPlace.key] of an AMTAB stop, followed by its index.
const transitStopKeyPrefix = 'stop:';

/// AMTAB stops are drawn from this zoom level, where they do not crowd the
/// map.
const transitStopsMinZoom = 15.0;

/// At most this many stops are drawn at once.
const _maxTransitStops = 200;

/// Places to draw on the map: the discovered ones, with the selected one
/// highlighted, and the favorites, always visible as stars in the color of
/// their folder.
///
/// A discovered place that is also a favorite keeps its own key, so that a
/// tap still opens its details, but is drawn with the star.
final mapPlacesProvider = Provider<List<MapPlace>>((ref) {
  final (places, category) = ref.watch(
    placeDiscoveryProvider.select((s) => (s.places, s.category)),
  );
  final favorites = ref.watch(favoritesProvider);
  final viewport = ref.watch(mapViewportProvider);
  final stops = viewport == null || viewport.zoom < transitStopsMinZoom
      ? const <TransitStop>[]
      : (ref.watch(transitDataProvider).value?.stops ?? const [])
            .where((stop) => viewport.bounds.containsPoint(stop.point))
            .take(_maxTransitStops)
            .toList();
  final folderColors = {
    for (final folder in ref.watch(favoriteFoldersProvider))
      folder.id: folder.colorIndex,
  };
  int? colorOf(String? folderId) =>
      folderId == null ? null : folderColors[folderId];
  final selectedKey = ref.watch(
    navigationControllerProvider.select((s) => s.selectedPlace?.ref.key),
  );
  final discovered = category == null
      ? const <String>{}
      : {for (final place in places) place.ref.key};
  // Favorite folder color by OpenStreetMap key; null outside any folder.
  final favoriteKeys = <String, int?>{
    for (final favorite in favorites)
      if (favorite.osmRef case final ref?) ref.key: colorOf(favorite.folderId),
  };
  return [
    for (final stop in stops)
      MapPlace(
        key: '$transitStopKeyPrefix${stop.index}',
        point: stop.point,
        imageId: TransitMarker.imageId,
        color: TransitMarker.color,
        column: false,
      ),
    if (category != null)
      for (final place in places)
        if (favoriteKeys.containsKey(place.ref.key))
          MapPlace(
            key: place.ref.key,
            point: place.point,
            imageId: FavoriteMarker.imageOf(favoriteKeys[place.ref.key]),
            color: FavoriteMarker.colorOf(favoriteKeys[place.ref.key]),
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
          imageId: FavoriteMarker.imageOf(colorOf(favorite.folderId)),
          color: FavoriteMarker.colorOf(colorOf(favorite.folderId)),
          name: favorite.name,
        ),
  ];
});
