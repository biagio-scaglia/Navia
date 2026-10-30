import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/navia_tokens.dart';
import '../../../../shared/models/geo_point.dart';
import '../../data/maplibre_navia_map_controller.dart';
import '../../domain/map_camera.dart';
import '../../domain/map_overlays.dart';
import '../../domain/navia_map_controller.dart';

/// Renders the map with MapLibre Native.
///
/// This widget and [MapLibreNaviaMapController] are the only places that
/// know about MapLibre; everything else talks to [NaviaMapController].
/// The platform view stays mounted for the lifetime of the map screen: style
/// and overlay changes are applied to the existing native map.
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
    required this.onLongPress,
  });

  final String styleUrl;
  final MapCamera initialCamera;

  /// Shows the user location indicator, fed through
  /// [NaviaMapController.showUserLocation]. MapLibre never reads the device
  /// location itself.
  final bool showUserLocation;

  /// Insets for the native compass (top/right) and attribution (top/left)
  /// so they do not collide with Flutter overlays.
  final EdgeInsets controlsPadding;

  final ValueChanged<NaviaMapController> onMapReady;
  final VoidCallback onStyleLoadStarted;

  /// Called once the style and Navia's overlay layers are ready.
  final VoidCallback onStyleLoaded;

  final ValueChanged<GeoPoint> onLongPress;

  @override
  State<NaviaMapView> createState() => _NaviaMapViewState();
}

class _NaviaMapViewState extends State<NaviaMapView> {
  MapLibreNaviaMapController? _controller;
  late MapOverlayStyle _overlayStyle;

  @override
  void initState() {
    super.initState();
    _notifyLoadStarted();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlayStyle = _overlayStyleFor(Theme.of(context));
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
    final adapter = MapLibreNaviaMapController(controller);
    _controller = adapter;
    widget.onMapReady(adapter);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.installOverlays(_overlayStyle);
    } on Exception catch (error) {
      // The map stays usable without overlays; report it for debugging.
      debugPrint('[map] could not install overlays: $error');
    }
    if (mounted) widget.onStyleLoaded();
  }

  void _onLongPress(Point<double> _, LatLng coordinates) {
    final point = GeoPoint.tryCreate(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (point != null) widget.onLongPress(point);
  }

  static MapOverlayStyle _overlayStyleFor(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return MapOverlayStyle(
      route: dark ? NaviaColors.brandLight : NaviaColors.brand,
      routeCasing: dark ? NaviaColors.routeCasingDark : NaviaColors.routeCasing,
      origin: dark ? NaviaColors.aquaLight : NaviaColors.aqua,
      destination: dark ? NaviaColors.destinationDark : NaviaColors.destination,
      selection: theme.colorScheme.onSurface,
      markerStroke: dark ? NaviaColors.surfaceDark : Colors.white,
    );
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
      onStyleLoadedCallback: _onStyleLoaded,
      onMapLongClick: _onLongPress,
      locationSource: const ManualLocationSource(),
      myLocationEnabled: widget.showUserLocation,
      compassViewPosition: CompassViewPosition.topRight,
      compassViewMargins: Point(padding.right, padding.top),
      attributionButtonPosition: AttributionButtonPosition.topLeft,
      attributionButtonMargins: Point(padding.left, padding.top),
      attributionButtonColor: Theme.of(context).colorScheme.onSurfaceVariant,
      foregroundLoadColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
