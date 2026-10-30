import 'package:flutter/painting.dart';

import '../../../shared/models/geo_point.dart';
import 'map_overlays.dart';

/// Commands that features can issue to the map, independent of the renderer.
///
/// Features such as search and routing depend on this interface rather than
/// on the MapLibre controller.
abstract interface class NaviaMapController {
  /// Moves the camera to [target], optionally changing the [zoom] level.
  Future<void> moveTo(GeoPoint target, {double? zoom, bool animated = true});

  /// Moves the camera so that all [points] are visible inside [padding].
  Future<void> fitBounds(List<GeoPoint> points, {EdgeInsets padding});

  /// Draws the user location indicator at [point].
  Future<void> showUserLocation(
    GeoPoint point, {
    double? accuracyMeters,
    double? headingDegrees,
  });

  /// Draws a route line along [geometry]; an empty list removes it.
  Future<void> showRoute(List<GeoPoint> geometry);

  /// Replaces all markers drawn by Navia.
  Future<void> showMarkers(List<MapMarker> markers);
}
