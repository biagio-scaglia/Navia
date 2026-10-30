import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/map_control_button.dart';
import '../../../core/widgets/navia_icon.dart';
import '../../../shared/models/geo_point.dart';
import '../../location/domain/location_models.dart';
import '../../location/presentation/location_controller.dart';
import '../../location/presentation/location_failure_messages.dart';
import '../../location/presentation/widgets/location_button.dart';
import '../../navigation/domain/navigation_models.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../navigation/presentation/navigation_overlays.dart';
import '../../navigation/presentation/widgets/navigation_sheet.dart';
import '../../search/data/photon_geocoding_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../domain/navia_map_controller.dart';
import 'map_preferences_controller.dart';
import 'map_providers.dart';
import 'widgets/map_attribution.dart';
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
  }

  void _syncOverlays() {
    final map = _map;
    if (map == null) return;
    unawaited(map.showRoute(ref.read(routeGeometryProvider)));
    unawaited(map.showMarkers(ref.read(mapMarkersProvider)));
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
      ),
    );
    await _map?.moveTo(place.point, zoom: AppConfig.userLocationZoom);
  }

  void _onLongPress(GeoPoint point) {
    unawaited(HapticFeedback.selectionClick());
    _navigation.select(PointWaypoint(point));
  }

  /// Frames [geometry] in the part of the map not covered by overlays.
  void _fitRoute(List<GeoPoint> geometry) {
    final map = _map;
    if (map == null || geometry.isEmpty) return;
    final safe = MediaQuery.paddingOf(context);
    final sheetHeight = _sheetKey.currentContext?.size?.height ?? 0;
    unawaited(
      map.fitBounds(
        geometry,
        padding: EdgeInsets.fromLTRB(
          48,
          safe.top + MapTopBar.height + 48,
          48,
          safe.bottom + sheetHeight + 48,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safe = MediaQuery.paddingOf(context);
    final controlsTop = safe.top + _edge + MapTopBar.height + NaviaSpacing.md;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
                onLongPress: _onLongPress,
              ),
            ),
            Positioned.fill(child: _MapStatusLayer(onRetry: _retryMap)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(_edge),
                child: _MapOverlays(
                  sheetKey: _sheetKey,
                  onOpenSearch: _openSearch,
                  onLocationPressed: _onLocationPressed,
                  onShowRoute: () => _fitRoute(ref.read(routeGeometryProvider)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The map itself. Rebuilds only when the style or location puck changes.
class _MapLayer extends ConsumerWidget {
  const _MapLayer({
    required this.controlsPadding,
    required this.onMapReady,
    required this.onStyleLoaded,
    required this.onLongPress,
  });

  final EdgeInsets controlsPadding;
  final ValueChanged<NaviaMapController> onMapReady;
  final VoidCallback onStyleLoaded;
  final ValueChanged<GeoPoint> onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final style = ref.watch(
      mapPreferencesProvider.select((p) => p.appearance.resolve(brightness)),
    );
    final styleUrl = ref.watch(
      mapStyleSourceProvider.select((s) => s.urlFor(style)),
    );
    final attempt = ref.watch(
      mapLoadControllerProvider.select((s) => s.attempt),
    );
    final hasPosition = ref.watch(
      locationControllerProvider.select((s) => s.position != null),
    );

    return NaviaMapView(
      // A new key recreates the platform view, only on explicit retry.
      key: ValueKey(attempt),
      styleUrl: styleUrl,
      initialCamera: AppConfig.initialCamera,
      showUserLocation: hasPosition,
      controlsPadding: controlsPadding,
      onMapReady: onMapReady,
      onStyleLoadStarted: ref
          .read(mapLoadControllerProvider.notifier)
          .loadStarted,
      onStyleLoaded: onStyleLoaded,
      onLongPress: onLongPress,
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
    required this.onShowRoute,
  });

  final GlobalKey sheetKey;
  final VoidCallback onOpenSearch;
  final VoidCallback onLocationPressed;
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

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: MapTopBar(
              onOpenSettings: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
              onSearch: searchAvailable && mapReady ? onOpenSearch : null,
            ),
          ),
        ),
        if (mapReady) ...[
          Padding(
            padding: const EdgeInsets.only(top: NaviaSpacing.md, left: 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MapAttributionChip(source: source),
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: _MapControls(
              onLocationPressed: onLocationPressed,
              onShowRoute: onShowRoute,
            ),
          ),
          const SizedBox(height: NaviaSpacing.md),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: NavigationSheet(key: sheetKey),
            ),
          ),
        ],
      ],
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
