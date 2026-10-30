import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../app/config/app_config.dart';
import '../../data/maplibre_navia_map_controller.dart';
import '../../domain/map_camera.dart';
import '../../domain/navia_map_controller.dart';

/// Renders the map with MapLibre Native.
///
/// This widget and [MapLibreNaviaMapController] are the only places that
/// know about MapLibre; everything else talks to [NaviaMapController].
class NaviaMapView extends StatefulWidget {
  const NaviaMapView({
    super.key,
    required this.styleUrl,
    required this.initialCamera,
    required this.showUserLocation,
    required this.controlsPadding,
    required this.onMapReady,
    required this.onStyleLoadStarted,
    required this.onStyleLoaded,
  });

  final String styleUrl;
  final MapCamera initialCamera;

  /// Shows the user location indicator, fed through
  /// [NaviaMapController.showUserLocation]. MapLibre never reads the device
  /// location itself.
  final bool showUserLocation;

  /// Insets for the native compass (top/right) and attribution (bottom/left)
  /// so they do not collide with Flutter overlays.
  final EdgeInsets controlsPadding;

  final ValueChanged<NaviaMapController> onMapReady;
  final VoidCallback onStyleLoadStarted;
  final VoidCallback onStyleLoaded;

  @override
  State<NaviaMapView> createState() => _NaviaMapViewState();
}

class _NaviaMapViewState extends State<NaviaMapView> {
  @override
  void initState() {
    super.initState();
    _notifyLoadStarted();
  }

  @override
  void didUpdateWidget(NaviaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.styleUrl != widget.styleUrl) _notifyLoadStarted();
  }

  // Deferred so that listeners can update state outside of build.
  void _notifyLoadStarted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStyleLoadStarted();
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    widget.onMapReady(MapLibreNaviaMapController(controller));
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.initialCamera;
    final padding = widget.controlsPadding;

    return MapLibreMap(
      styleString: widget.styleUrl,
      initialCameraPosition: CameraPosition(
        target: MapLibreNaviaMapController.toLatLng(camera.target),
        zoom: camera.zoom,
        bearing: camera.bearing,
        tilt: camera.tilt,
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(
        AppConfig.minZoom,
        AppConfig.maxZoom,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: widget.onStyleLoaded,
      locationSource: const ManualLocationSource(),
      myLocationEnabled: widget.showUserLocation,
      compassViewPosition: CompassViewPosition.topRight,
      compassViewMargins: Point(padding.right, padding.top),
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      attributionButtonMargins: Point(padding.left, padding.bottom),
      attributionButtonColor: Theme.of(context).colorScheme.onSurfaceVariant,
      foregroundLoadColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
