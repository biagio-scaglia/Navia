import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../app/config/app_config.dart';
import '../../../shared/models/geo_point.dart';
import '../domain/map_overlays.dart';
import '../domain/navia_map_controller.dart';
import 'map_feature_parser.dart';
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
  static const _routeCasingLayer = 'navia-route-casing';
  static const _buildingsLayer = 'navia-buildings-3d';

  /// Building extrusion layer that some styles (e.g. OpenFreeMap Liberty)
  /// already include; Navia then only tilts the camera.
  static const _styleBuildingsLayer = 'building-3d';

  static const _pitch3d = AppConfig.pitch3d;

  /// Tap tolerance around the touch point when looking for POIs, in the
  /// pixel units of the map tap callback.
  static const _tapTolerance = 24.0;

  final MapLibreMapController _controller;

  List<GeoPoint> _route = const [];
  List<MapMarker> _markers = const [];
  bool _overlaysReady = false;

  MapOverlayStyle? _style;
  ({String sourceId, String sourceLayer})? _buildingsSource;
  bool _buildings3d = false;
  bool _styleHasBuildings3d = false;
  bool _buildingsLayerAdded = false;
  List<String> _poiLayers = const [];
  CameraPosition? _cameraBeforeStyleChange;

  /// MapLibre's [LatLng] takes latitude first, unlike GeoJSON.
  static LatLng toLatLng(GeoPoint point) =>
      LatLng(point.latitude, point.longitude);

  /// Remembers the camera before a new style is applied, so that
  /// [restoreCamera] can undo a reset caused by the style switch.
  Future<void> captureCamera() async {
    _cameraBeforeStyleChange = await _controller.queryCameraPosition();
  }

  /// Puts back the camera captured by [captureCamera] if the new style moved
  /// it (target, zoom, bearing and pitch are all preserved).
  Future<void> restoreCamera() async {
    final saved = _cameraBeforeStyleChange;
    _cameraBeforeStyleChange = null;
    if (saved == null) return;
    final current = await _controller.queryCameraPosition();
    if (current != null && _sameCamera(current, saved)) return;
    await _controller.moveCamera(CameraUpdate.newCameraPosition(saved));
  }

  static bool _sameCamera(CameraPosition a, CameraPosition b) =>
      (a.target.latitude - b.target.latitude).abs() < 1e-6 &&
      (a.target.longitude - b.target.longitude).abs() < 1e-6 &&
      (a.zoom - b.zoom).abs() < 1e-3 &&
      (a.bearing - b.bearing).abs() < 1e-2 &&
      (a.tilt - b.tilt).abs() < 1e-2;

  /// Adds Navia's sources and layers to a freshly loaded style.
  ///
  /// [buildingsSource] names the vector source layer with building heights;
  /// null disables 3D buildings for styles that do not include them.
  Future<void> installOverlays(
    MapOverlayStyle style, {
    required bool buildings3d,
    ({String sourceId, String sourceLayer})? buildingsSource,
  }) async {
    _overlaysReady = false;
    _style = style;
    _buildings3d = buildings3d;
    _buildingsSource = buildingsSource;
    _buildingsLayerAdded = false;
    await _controller.addGeoJsonSource(
      _routeSource,
      MapOverlayGeoJson.route(_route),
    );
    await _controller.addLineLayer(
      _routeSource,
      _routeCasingLayer,
      LineLayerProperties(
        lineColor: _hex(style.routeCasing),
        lineWidth: _zoomWidth(base: 6, max: 14),
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
        lineWidth: _zoomWidth(base: 3.5, max: 9),
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
          MapMarkerKind.destination.name,
          10,
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

    final layerIds = (await _controller.getLayerIds()).whereType<String>();
    _styleHasBuildings3d = layerIds.contains(_styleBuildingsLayer);
    // OpenMapTiles-based styles name POI label layers "poi_*".
    _poiLayers = [
      for (final id in layerIds)
        if (id.startsWith('poi')) id,
    ];
    _overlaysReady = true;
    await _applyBuildingsLayer();
  }

  /// Route width that grows with zoom, so the line stays readable when the
  /// whole route is framed and does not hide streets when zoomed in.
  static List<Object> _zoomWidth({required double base, required double max}) =>
      [
        'interpolate',
        ['linear'],
        ['zoom'],
        10,
        base,
        18,
        max,
      ];

  @override
  Future<void> setBuildings3d(bool enabled) async {
    _buildings3d = enabled;
    await _applyBuildingsLayer();
    await _controller.animateCamera(
      CameraUpdate.tiltTo(enabled ? _pitch3d : 0),
      duration: _cameraDuration,
    );
  }

  /// Adds or removes Navia's extrusion layer. Heights come only from the
  /// tile data; buildings without height information stay flat.
  Future<void> _applyBuildingsLayer() async {
    final source = _buildingsSource;
    final style = _style;
    if (!_overlaysReady || _styleHasBuildings3d) return;
    if (_buildings3d && !_buildingsLayerAdded) {
      if (source == null || style == null) return;
      await _controller.addFillExtrusionLayer(
        source.sourceId,
        _buildingsLayer,
        FillExtrusionLayerProperties(
          fillExtrusionColor: _hex(style.buildings),
          fillExtrusionHeight: ['get', 'render_height'],
          fillExtrusionBase: ['get', 'render_min_height'],
          fillExtrusionOpacity: 0.8,
        ),
        sourceLayer: source.sourceLayer,
        minzoom: 14,
        filter: [
          '!',
          ['has', 'hide_3d'],
        ],
        // Keeps the route and markers drawn above the buildings.
        belowLayerId: _routeCasingLayer,
        enableInteraction: false,
      );
      _buildingsLayerAdded = true;
    } else if (!_buildings3d && _buildingsLayerAdded) {
      await _controller.removeLayer(_buildingsLayer);
      _buildingsLayerAdded = false;
    }
  }

  @override
  Future<MapPoi?> poiAt(Offset screenPoint) async {
    if (_poiLayers.isEmpty) return null;
    final features = await _controller.queryRenderedFeaturesInRect(
      Rect.fromCenter(
        center: screenPoint,
        width: _tapTolerance * 2,
        height: _tapTolerance * 2,
      ),
      _poiLayers,
      null,
    );
    return MapFeatureParser.firstPoi(features);
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
