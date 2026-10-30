import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/floating_surface.dart';
import '../../../core/widgets/map_control_button.dart';
import '../../../core/widgets/navia_icon.dart';
import '../../../shared/models/geo_point.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../location/domain/location_models.dart';
import '../../location/presentation/location_controller.dart';
import '../../location/presentation/location_failure_messages.dart';
import '../../location/presentation/widgets/location_button.dart';
import '../../navigation/domain/navigation_models.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../navigation/presentation/navigation_overlays.dart';
import '../../navigation/presentation/widgets/navigation_sheet.dart';
import '../../places/presentation/place_discovery_controller.dart';
import '../../places/presentation/place_overlays.dart';
import '../../places/presentation/widgets/place_category_bar.dart';
import '../../search/data/photon_geocoding_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../domain/navia_map_controller.dart';
import 'map_preferences_controller.dart';
import 'map_providers.dart';
import 'widgets/map_attribution.dart';
import 'widgets/map_layers_sheet.dart';
import 'widgets/map_status_views.dart';
import 'widgets/map_top_bar.dart';
import 'widgets/navia_map_view.dart';

/// Main screen: a fullscreen map with minimal floating controls.
///
/// This widget watches no provider in `build`: each overlay subscribes to the
/// slice of state it shows, and map side effects run in `ref.listen`
/// callbacks. The map view therefore rebuilds only when its own inputs
/// (style, user location visibility) change.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _edge = NaviaSpacing.lg;

  final _sheetKey = GlobalKey();
  NaviaMapController? _map;
  late final AppLifecycleListener _lifecycle;

  LocationController get _location =>
      ref.read(locationControllerProvider.notifier);

  NavigationController get _navigation =>
      ref.read(navigationControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Location updates are only needed while the map is visible.
    _lifecycle = AppLifecycleListener(
      onHide: () => _location.pause(),
      onShow: () => _location.resume(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onMapReady(NaviaMapController controller) => _map = controller;

  void _onStyleLoaded() {
    ref.read(mapLoadControllerProvider.notifier).styleLoaded();
    // A new style starts empty: restore the indicator and overlays.
    _showUserLocation(ref.read(locationControllerProvider).position);
    _syncOverlays();
    unawaited(_reportViewport());
  }

  void _syncOverlays() {
    final map = _map;
    if (map == null) return;
    unawaited(map.showRoute(ref.read(routeGeometryProvider)));
    unawaited(map.showMarkers(ref.read(mapMarkersProvider)));
    unawaited(map.showPlaces(ref.read(mapPlacesProvider)));
    unawaited(
      map.setStylePoisVisible(
        ref.read(placeDiscoveryProvider).category == null,
      ),
    );
  }

  /// Tells place discovery which area is shown, once the camera is idle.
  Future<void> _reportViewport() async {
    final viewport = await _map?.viewport();
    if (!mounted || viewport == null) return;
    ref
        .read(placeDiscoveryProvider.notifier)
        .viewportChanged(viewport.bounds, viewport.zoom);
  }

  void _retryMap() {
    _map = null;
    ref.read(mapLoadControllerProvider.notifier).retry();
  }

  void _showUserLocation(UserPosition? position) {
    final map = _map;
    if (map == null || position == null) return;
    unawaited(
      map.showUserLocation(
        position.point,
        accuracyMeters: position.accuracyMeters,
        headingDegrees: position.headingDegrees,
      ),
    );
  }

  Future<void> _onLocationPressed() async {
    final position = await _location.locate();
    if (!mounted || position == null) return;
    await _map?.moveTo(position.point, zoom: AppConfig.userLocationZoom);
  }

  Future<void> _openSearch() async {
    final pick = await SearchScreen.open(context);
    if (!mounted || pick is! PlacePick) return;
    final place = pick.place;
    _navigation.select(
      PointWaypoint(
        place.point,
        label: place.name,
        description: place.description,
        category: place.category,
      ),
    );
    await _map?.moveTo(place.point, zoom: AppConfig.userLocationZoom);
  }

  /// A tap selects the named place under the finger, if the style draws
  /// one there; a tap on an empty spot dismisses the current selection.
  Future<void> _onTap(Offset screenPoint, GeoPoint point) async {
    final placeKey = await _map?.placeKeyAt(screenPoint);
    if (!mounted) return;
    final place = placeKey == null
        ? null
        : ref.read(placeDiscoveryProvider.notifier).placeByKey(placeKey);
    if (place != null) {
      _navigation.selectPlace(place);
      return;
    }
    final poi = await _map?.poiAt(screenPoint);
    if (!mounted) return;
    if (poi == null) {
      _navigation.clearSelection();
      return;
    }
    _navigation.select(
      PointWaypoint(poi.point, label: poi.name, description: poi.category),
    );
  }

  Future<void> _openFavorites() async {
    final favorite = await FavoritesScreen.open(context);
    if (!mounted || favorite == null) return;
    _navigation.select(PointWaypoint(favorite.point, label: favorite.name));
    await _map?.moveTo(favorite.point, zoom: AppConfig.userLocationZoom);
  }

  void _onLongPress(GeoPoint point) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(_navigation.selectPoint(point));
  }

  /// Frames [geometry] in the part of the map not covered by overlays.
  void _fitRoute(List<GeoPoint> geometry) {
    final map = _map;
    if (map == null || geometry.isEmpty) return;
    final safe = MediaQuery.paddingOf(context);
    final sheetHeight = _sheetKey.currentContext?.size?.height ?? 0;
    // Keeps the route clear of the control column on the right.
    const controls = _edge + NaviaSizes.mapControl + _edge;
    unawaited(
      map.fitBounds(
        geometry,
        padding: EdgeInsets.fromLTRB(
          safe.left + 40,
          safe.top + MapTopBar.height + 48,
          safe.right + controls,
          sheetHeight + 40,
        ),
      ),
    );
  }

  void _showLocationFailure(LocationFailure failure) {
    final actionLabel = failure.actionLabel;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure.message),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  onPressed: () => _location.openSettingsFor(failure),
                ),
        ),
      );
  }

  void _listenToState() {
    ref.listen(locationControllerProvider, (previous, next) {
      if (next.position != previous?.position) {
        _showUserLocation(next.position);
      }
      // Route failures are reported in the sheet instead.
      final failure = next.failure;
      final calculatingRoute =
          ref.read(navigationControllerProvider).routeStatus ==
          RouteStatus.loading;
      if (failure != null &&
          previous?.status != LocationStatus.failed &&
          !calculatingRoute) {
        _showLocationFailure(failure);
      }
    });
    ref.listen(mapMarkersProvider, (_, markers) {
      unawaited(_map?.showMarkers(markers));
    });
    ref.listen(mapPlacesProvider, (_, places) {
      unawaited(_map?.showPlaces(places));
    });
    ref.listen(placeDiscoveryProvider.select((s) => s.category), (_, category) {
      // The style's own labels would duplicate the discovered places.
      unawaited(_map?.setStylePoisVisible(category == null));
    });
    ref.listen(routeGeometryProvider, (_, geometry) {
      unawaited(_map?.showRoute(geometry));
      // Wait for the sheet to lay out its summary before measuring it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitRoute(geometry);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _listenToState();
    final safe = MediaQuery.paddingOf(context);
    final controlsTop = safe.top + _edge + MapTopBar.height + NaviaSpacing.md;

    return _BackHandler(
      child: _MapSystemBars(
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(
                child: _MapLayer(
                  controlsPadding: EdgeInsets.fromLTRB(
                    _edge + safe.left,
                    controlsTop,
                    _edge + safe.right,
                    _edge + safe.bottom,
                  ),
                  onMapReady: _onMapReady,
                  onStyleLoaded: _onStyleLoaded,
                  onTap: _onTap,
                  onLongPress: _onLongPress,
                  onCameraIdle: () => unawaited(_reportViewport()),
                ),
              ),
              Positioned.fill(child: _MapStatusLayer(onRetry: _retryMap)),
              Positioned.fill(
                child: _MapOverlays(
                  sheetKey: _sheetKey,
                  onOpenSearch: _openSearch,
                  onLocationPressed: _onLocationPressed,
                  onOpenFavorites: _openFavorites,
                  onShowRoute: () => _fitRoute(ref.read(routeGeometryProvider)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the back gesture first dismiss the selection, the route plan and the
/// place filter, and only then leave the app.
class _BackHandler extends ConsumerWidget {
  const _BackHandler({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planning = ref.watch(
      navigationControllerProvider.select(
        (s) => s.selection != null || s.isPlanning,
      ),
    );
    final discovering = ref.watch(
      placeDiscoveryProvider.select((s) => s.category != null),
    );
    return PopScope(
      canPop: !planning && !discovering,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navigation = ref.read(navigationControllerProvider.notifier);
        final state = ref.read(navigationControllerProvider);
        if (state.selection != null) {
          navigation.clearSelection();
        } else if (state.isPlanning) {
          navigation.clear();
        } else {
          ref.read(placeDiscoveryProvider.notifier).select(null);
        }
      },
      child: child,
    );
  }
}

/// Transparent, edge-to-edge system bars whose icons contrast with the map
/// style actually shown, which may differ from the app theme.
class _MapSystemBars extends ConsumerWidget {
  const _MapSystemBars({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final darkMap = ref.watch(
      mapPreferencesProvider.select(
        (p) => p.appearance.resolve(brightness).isDark,
      ),
    );
    final iconBrightness = darkMap ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: darkMap ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconBrightness,
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}

/// The map itself. Rebuilds only when the style or location puck changes.
class _MapLayer extends ConsumerWidget {
  const _MapLayer({
    required this.controlsPadding,
    required this.onMapReady,
    required this.onStyleLoaded,
    required this.onTap,
    required this.onLongPress,
    required this.onCameraIdle,
  });

  final EdgeInsets controlsPadding;
  final ValueChanged<NaviaMapController> onMapReady;
  final VoidCallback onStyleLoaded;
  final void Function(Offset screenPoint, GeoPoint point) onTap;
  final ValueChanged<GeoPoint> onLongPress;
  final VoidCallback onCameraIdle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final style = ref.watch(
      mapPreferencesProvider.select((p) => p.appearance.resolve(brightness)),
    );
    final buildings3d = ref.watch(
      mapPreferencesProvider.select((p) => p.buildings3d),
    );
    final source = ref.watch(mapStyleSourceProvider);
    final attempt = ref.watch(
      mapLoadControllerProvider.select((s) => s.attempt),
    );

    return NaviaMapView(
      // A new key recreates the platform view, only on explicit retry.
      key: ValueKey(attempt),
      source: source,
      style: style,
      buildings3d: buildings3d,
      initialCamera: AppConfig.initialCamera,
      controlsPadding: controlsPadding,
      onMapReady: onMapReady,
      onStyleLoadStarted: ref
          .read(mapLoadControllerProvider.notifier)
          .loadStarted,
      onStyleLoaded: onStyleLoaded,
      onTap: onTap,
      onLongPress: onLongPress,
      onCameraIdle: onCameraIdle,
    );
  }
}

class _MapStatusLayer extends ConsumerWidget {
  const _MapStatusLayer({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(mapLoadControllerProvider);
    if (load.status == MapLoadStatus.failed) {
      return MapErrorView(onRetry: onRetry);
    }
    if (!load.hasLoaded) return const MapLoadingView();
    return const SizedBox.shrink();
  }
}

/// Search bar, map controls and navigation sheet.
class _MapOverlays extends ConsumerWidget {
  const _MapOverlays({
    required this.sheetKey,
    required this.onOpenSearch,
    required this.onLocationPressed,
    required this.onOpenFavorites,
    required this.onShowRoute,
  });

  final GlobalKey sheetKey;
  final VoidCallback onOpenSearch;
  final VoidCallback onLocationPressed;
  final VoidCallback onOpenFavorites;
  final VoidCallback onShowRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapReady = ref.watch(
      mapLoadControllerProvider.select((s) => s.hasLoaded),
    );
    final searchAvailable = ref.watch(
      geocodingRepositoryProvider.select((r) => r != null),
    );
    final source = ref.watch(mapStyleSourceProvider);

    final safe = MediaQuery.paddingOf(context);
    const edge = NaviaSpacing.lg;

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              edge + safe.left,
              edge + safe.top,
              edge + safe.right,
              0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: NaviaSizes.panelMaxWidth,
                ),
                child: MapTopBar(
                  onOpenSettings: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                  onOpenFavorites: onOpenFavorites,
                  onSearch: searchAvailable && mapReady ? onOpenSearch : null,
                ),
              ),
            ),
          ),
          if (mapReady) ...[
            Padding(
              padding: const EdgeInsets.only(top: NaviaSpacing.md),
              child: PlaceCategoryBar(
                padding: EdgeInsets.only(
                  left: edge + safe.left,
                  right: edge + safe.right,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                edge + safe.left,
                NaviaSpacing.md,
                edge + safe.right,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MapAttributionChip(source: source),
                  const Spacer(),
                  const _MapViewControls(),
                ],
              ),
            ),
          ],
          if (mapReady) ...[
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    edge,
                    edge,
                    edge + safe.right,
                    NaviaSpacing.md,
                  ),
                  child: _MapControls(
                    onLocationPressed: onLocationPressed,
                    onShowRoute: onShowRoute,
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: NaviaSizes.panelMaxWidth,
                  // The map always keeps most of the screen.
                  maxHeight: constraints.maxHeight * 0.6,
                ),
                child: NavigationSheet(key: sheetKey),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

/// Map appearance and 3D toggle, grouped in one compact floating pill.
class _MapViewControls extends ConsumerWidget {
  const _MapViewControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final buildings3d = ref.watch(
      mapPreferencesProvider.select((p) => p.buildings3d),
    );
    final supports3d = ref.watch(
      mapStyleSourceProvider.select((s) => s.supportsBuildings3d),
    );

    return FloatingSurface(
      borderRadius: const BorderRadius.all(
        Radius.circular(NaviaSizes.mapControl / 2),
      ),
      child: SizedBox(
        width: NaviaSizes.mapControl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: NaviaSizes.mapControl,
              child: IconButton(
                tooltip: AppStrings.mapAppearance,
                onPressed: () => showMapLayersSheet(context),
                icon: const NaviaIcon(NaviaIcons.layers),
              ),
            ),
            if (supports3d) ...[
              const Divider(
                indent: NaviaSpacing.md,
                endIndent: NaviaSpacing.md,
              ),
              SizedBox.square(
                dimension: NaviaSizes.mapControl,
                child: IconButton(
                  tooltip: buildings3d
                      ? AppStrings.disable3d
                      : AppStrings.enable3d,
                  isSelected: buildings3d,
                  style: IconButton.styleFrom(
                    backgroundColor: buildings3d
                        ? scheme.primary.withValues(alpha: 0.14)
                        : null,
                  ),
                  onPressed: () => ref
                      .read(mapPreferencesProvider.notifier)
                      .setBuildings3d(!buildings3d),
                  icon: NaviaIcon(
                    NaviaIcons.cube,
                    color: buildings3d ? scheme.primary : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapControls extends ConsumerWidget {
  const _MapControls({
    required this.onLocationPressed,
    required this.onShowRoute,
  });

  final VoidCallback onLocationPressed;
  final VoidCallback onShowRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationStatus = ref.watch(
      locationControllerProvider.select((s) => s.status),
    );
    final hasRoute = ref.watch(
      routeGeometryProvider.select((geometry) => geometry.isNotEmpty),
    );
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasRoute) ...[
          MapControlButton(
            tooltip: AppStrings.showWholeRoute,
            onPressed: onShowRoute,
            child: NaviaIcon(NaviaIcons.route, color: accent),
          ),
          const SizedBox(height: NaviaSpacing.md),
        ],
        LocationButton(status: locationStatus, onPressed: onLocationPressed),
      ],
    );
  }
}
