import 'dart:typed_data';

import 'package:flutter/painting.dart';

import '../../../shared/models/geo_bounds.dart';
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

  /// Tilts the camera and extrudes buildings from their real heights, or
  /// returns to the flat top-down view.
  Future<void> setBuildings3d(bool enabled);

  /// The named point of interest drawn around [screenPoint], if any.
  /// [screenPoint] uses the units reported by the map tap callback.
  Future<MapPoi?> poiAt(Offset screenPoint);

  /// Replaces the discovered places drawn by Navia.
  Future<void> showPlaces(List<MapPlace> places);

  /// Registers the marker images referenced by [MapPlace.imageId], as PNG
  /// bytes; they are added again to every new style.
  Future<void> setPlaceImages(Map<String, Uint8List> images);

  /// The [MapPlace.key] of the discovered place under [screenPoint].
  Future<String?> placeKeyAt(Offset screenPoint);

  /// Shows or hides the style's own point of interest labels, so that they
  /// do not duplicate the discovered places.
  Future<void> setStylePoisVisible(bool visible);

  /// The visible area and zoom level, or null before the map is laid out.
  Future<({GeoBounds bounds, double zoom})?> viewport();
}
