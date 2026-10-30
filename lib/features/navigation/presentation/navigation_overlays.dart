import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/geo_point.dart';
import '../../map/domain/map_overlays.dart';
import '../domain/navigation_models.dart';
import 'navigation_controller.dart';

/// Markers for the planned waypoints and the current selection.
///
/// The user location is not included: the map draws it as its own puck.
/// Selecting a record means unrelated changes (e.g. route status) do not
/// produce a new list.
final mapMarkersProvider = Provider<List<MapMarker>>((ref) {
  final (origin, destination, selection) = ref.watch(
    navigationControllerProvider.select(
      (state) => (state.origin, state.destination, state.selection),
    ),
  );
  return [
    if (origin case PointWaypoint(:final point))
      MapMarker(point, MapMarkerKind.origin),
    if (destination case PointWaypoint(:final point))
      MapMarker(point, MapMarkerKind.destination),
    if (selection != null) MapMarker(selection.point, MapMarkerKind.selection),
  ];
});

/// Geometry of the calculated route, or an empty list.
final routeGeometryProvider = Provider<List<GeoPoint>>(
  (ref) => ref.watch(
    navigationControllerProvider.select(
      (state) => state.route?.geometry ?? const <GeoPoint>[],
    ),
  ),
);
