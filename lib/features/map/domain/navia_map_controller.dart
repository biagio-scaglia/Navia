import '../../../shared/models/geo_point.dart';

/// Commands that features can issue to the map, independent of the renderer.
///
/// Future features (search results, route previews) should depend on this
/// interface rather than on the MapLibre controller.
abstract interface class NaviaMapController {
  /// Moves the camera to [target], optionally changing the [zoom] level.
  Future<void> moveTo(GeoPoint target, {double? zoom, bool animated = true});

  Future<void> zoomIn();

  Future<void> zoomOut();

  /// Draws the user location indicator at [point].
  Future<void> showUserLocation(
    GeoPoint point, {
    double? accuracyMeters,
    double? headingDegrees,
  });
}
