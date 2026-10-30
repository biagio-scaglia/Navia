import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../shared/models/geo_point.dart';
import '../domain/map_overlays.dart';
import '../domain/navia_map_controller.dart';
import 'map_overlay_geojson.dart';

/// [NaviaMapController] implemented on top of MapLibre Native.
///
/// Route and markers are drawn with GeoJSON sources and style layers, which
/// the GPU renders without any Flutter widget per marker. Their content is
/// kept here so that it can be restored after the style changes.
class MapLibreNaviaMapController implements NaviaMapController {
  MapLibreNaviaMapController(this._controller);

  static const _cameraDuration = Duration(milliseconds: 900);

  static const _routeSource = 'navia-route';
  static const _markerSource = 'navia-markers';

  final MapLibreMapController _controller;

  List<GeoPoint> _route = const [];
  List<MapMarker> _markers = const [];
  bool _overlaysReady = false;

  /// MapLibre's [LatLng] takes latitude first, unlike GeoJSON.
  static LatLng toLatLng(GeoPoint point) =>
      LatLng(point.latitude, point.longitude);

  /// Adds Navia's sources and layers to a freshly loaded style.
  Future<void> installOverlays(MapOverlayStyle style) async {
    _overlaysReady = false;
    await _controller.addGeoJsonSource(
      _routeSource,
      MapOverlayGeoJson.route(_route),
    );
    await _controller.addLineLayer(
      _routeSource,
      'navia-route-casing',
      LineLayerProperties(
        lineColor: _hex(style.routeCasing),
        lineWidth: 9,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await _controller.addLineLayer(
      _routeSource,
      'navia-route-line',
      LineLayerProperties(
        lineColor: _hex(style.route),
        lineWidth: 5.5,
        lineJoin: 'round',
        lineCap: 'round',
      ),
      enableInteraction: false,
    );
    await _controller.addGeoJsonSource(
      _markerSource,
      MapOverlayGeoJson.markers(_markers),
    );
    await _controller.addCircleLayer(
      _markerSource,
      'navia-markers',
      CircleLayerProperties(
        circleRadius: [
          'match',
          ['get', 'kind'],
          MapMarkerKind.selection.name,
          7,
          8,
        ],
        circleColor: [
          'match',
          ['get', 'kind'],
          MapMarkerKind.origin.name,
          _hex(style.origin),
          MapMarkerKind.destination.name,
          _hex(style.destination),
          _hex(style.selection),
        ],
        circleStrokeWidth: 3,
        circleStrokeColor: _hex(style.markerStroke),
      ),
      enableInteraction: false,
    );
    _overlaysReady = true;
  }

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
  Future<void> fitBounds(
    List<GeoPoint> points, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    if (points.isEmpty) return;
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final point in points) {
      south = math.min(south, point.latitude);
      north = math.max(north, point.latitude);
      west = math.min(west, point.longitude);
      east = math.max(east, point.longitude);
    }
    await _controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
      duration: _cameraDuration,
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

  @override
  Future<void> showRoute(List<GeoPoint> geometry) async {
    if (identical(geometry, _route)) return;
    _route = geometry;
    if (!_overlaysReady) return;
    await _controller.setGeoJsonSource(
      _routeSource,
      MapOverlayGeoJson.route(geometry),
    );
  }

  @override
  Future<void> showMarkers(List<MapMarker> markers) async {
    if (listEquals(markers, _markers)) return;
    _markers = markers;
    if (!_overlaysReady) return;
    await _controller.setGeoJsonSource(
      _markerSource,
      MapOverlayGeoJson.markers(markers),
    );
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
