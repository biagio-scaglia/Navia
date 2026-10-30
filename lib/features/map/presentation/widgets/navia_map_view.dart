import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/navia_tokens.dart';
import '../../../../shared/models/geo_point.dart';
import '../../data/maplibre_navia_map_controller.dart';
import '../../domain/map_camera.dart';
import '../../domain/map_overlays.dart';
import '../../domain/map_style_source.dart';
import '../../domain/navia_map_controller.dart';

/// Renders the map with MapLibre Native.
///
/// This widget and [MapLibreNaviaMapController] are the only places that
/// know about MapLibre; everything else talks to [NaviaMapController].
/// The platform view stays mounted for the lifetime of the map screen: style,
/// 3D and overlay changes are applied to the existing native map.
class NaviaMapView extends StatefulWidget {
  const NaviaMapView({
    super.key,
    required this.source,
    required this.style,
    required this.buildings3d,
    required this.initialCamera,
    required this.controlsPadding,
    required this.onMapReady,
    required this.onStyleLoadStarted,
    required this.onStyleLoaded,
    required this.onTap,
    required this.onLongPress,
  });

  final MapStyleSource source;
  final MapStyleId style;

  /// Tilted camera with extruded buildings.
  final bool buildings3d;

  final MapCamera initialCamera;

  /// Insets for the native attribution button and, below it, the compass
  /// (both top/left), so they do not collide with Flutter overlays.
  final EdgeInsets controlsPadding;

  final ValueChanged<NaviaMapController> onMapReady;
  final VoidCallback onStyleLoadStarted;

  /// Called once the style and Navia's overlay layers are ready.
  final VoidCallback onStyleLoaded;

  /// A tap on the map, with the screen position for feature queries.
  final void Function(Offset screenPoint, GeoPoint point) onTap;

  final ValueChanged<GeoPoint> onLongPress;

  @override
  State<NaviaMapView> createState() => _NaviaMapViewState();
}

class _NaviaMapViewState extends State<NaviaMapView> {
  MapLibreNaviaMapController? _controller;

  String get _styleUrl => widget.source.urlFor(widget.style);

  @override
  void initState() {
    super.initState();
    _notifyLoadStarted();
  }

  @override
  void didUpdateWidget(NaviaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (oldWidget.source.urlFor(oldWidget.style) != _styleUrl) {
      // Sent before MapLibre receives the new style, so the camera query is
      // answered with the position the user was looking at.
      if (controller != null) unawaited(controller.captureCamera());
      _notifyLoadStarted();
    }
    if (oldWidget.buildings3d != widget.buildings3d && controller != null) {
      unawaited(controller.setBuildings3d(widget.buildings3d));
    }
  }

  // Deferred so that listeners can update state outside of build.
  void _notifyLoadStarted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStyleLoadStarted();
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    final adapter = MapLibreNaviaMapController(controller);
    _controller = adapter;
    widget.onMapReady(adapter);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    final source = widget.source;
    try {
      await controller.installOverlays(
        _overlayStyleFor(widget.style),
        buildings3d: widget.buildings3d,
        buildingsSource: source.supportsBuildings3d
            ? (
                sourceId: source.buildingsSourceId!,
                sourceLayer: source.buildingsSourceLayer!,
              )
            : null,
      );
      await controller.restoreCamera();
    } on Exception catch (error) {
      // The map stays usable without overlays; report it for debugging.
      debugPrint('[map] could not install overlays: $error');
    }
    if (mounted) widget.onStyleLoaded();
  }

  void _onTap(Point<double> screenPoint, LatLng coordinates) {
    final point = GeoPoint.tryCreate(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (point != null) {
      widget.onTap(Offset(screenPoint.x, screenPoint.y), point);
    }
  }

  void _onLongPress(Point<double> _, LatLng coordinates) {
    final point = GeoPoint.tryCreate(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (point != null) widget.onLongPress(point);
  }

  /// Overlay colors follow the map style, not the app theme, so they stay
  /// readable when, e.g., a dark map is shown in the light theme.
  static MapOverlayStyle _overlayStyleFor(MapStyleId style) {
    final dark = style.isDark;
    return MapOverlayStyle(
      route: dark ? NaviaColors.brandLight : NaviaColors.brand,
      routeCasing: dark ? NaviaColors.routeCasingDark : NaviaColors.routeCasing,
      origin: dark ? NaviaColors.aquaLight : NaviaColors.aqua,
      destination: dark ? NaviaColors.destinationDark : NaviaColors.destination,
      selection: dark ? NaviaColors.inkDark : NaviaColors.inkLight,
      markerStroke: dark ? NaviaColors.surfaceDark : Colors.white,
      buildings: dark ? NaviaColors.buildingDark : NaviaColors.building,
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.initialCamera;
    final padding = widget.controlsPadding;

    return MapLibreMap(
      styleString: _styleUrl,
      initialCameraPosition: CameraPosition(
        target: MapLibreNaviaMapController.toLatLng(camera.target),
        zoom: camera.zoom,
        bearing: camera.bearing,
        tilt: widget.buildings3d ? AppConfig.pitch3d : camera.tilt,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(
        AppConfig.minZoom,
        AppConfig.maxZoom,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onMapClick: _onTap,
      onMapLongClick: _onLongPress,
      // The location component must exist before the first position is
      // pushed through [NaviaMapController.showUserLocation]; it draws
      // nothing until then. MapLibre never reads the device location itself.
      locationSource: const ManualLocationSource(),
      myLocationEnabled: true,
      // The compass appears only when the map is rotated; tapping it turns
      // north back up.
      compassViewPosition: CompassViewPosition.topLeft,
      compassViewMargins: Point(padding.left, padding.top + 48),
      // The native button sits under the bottom panel: the same notices are
      // shown by the always-visible attribution chip, which links to them.
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: const Point(0, 0),
      foregroundLoadColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
