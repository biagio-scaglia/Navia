import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../shared/models/geo_point.dart';
import '../domain/navia_map_controller.dart';

/// [NaviaMapController] implemented on top of MapLibre Native.
class MapLibreNaviaMapController implements NaviaMapController {
  MapLibreNaviaMapController(this._controller);

  static const _cameraDuration = Duration(milliseconds: 900);
  static const _zoomDuration = Duration(milliseconds: 250);

  final MapLibreMapController _controller;

  /// MapLibre's [LatLng] takes latitude first, unlike GeoJSON.
  static LatLng toLatLng(GeoPoint point) =>
      LatLng(point.latitude, point.longitude);

  @override
  Future<void> moveTo(
    GeoPoint target, {
    double? zoom,
    bool animated = true,
  }) async {
    final latLng = toLatLng(target);
    final update = zoom == null
        ? CameraUpdate.newLatLng(latLng)
        : CameraUpdate.newLatLngZoom(latLng, zoom);
    if (animated) {
      await _controller.animateCamera(update, duration: _cameraDuration);
    } else {
      await _controller.moveCamera(update);
    }
  }

  @override
  Future<void> zoomIn() async {
    await _controller.animateCamera(
      CameraUpdate.zoomIn(),
      duration: _zoomDuration,
    );
  }

  @override
  Future<void> zoomOut() async {
    await _controller.animateCamera(
      CameraUpdate.zoomOut(),
      duration: _zoomDuration,
    );
  }

  @override
  Future<void> showUserLocation(
    GeoPoint point, {
    double? accuracyMeters,
    double? headingDegrees,
  }) => _controller.updateManualLocation(
    ManualLocationUpdate(
      target: toLatLng(point),
      horizontalAccuracy: accuracyMeters,
      bearing: headingDegrees,
    ),
  );
}
