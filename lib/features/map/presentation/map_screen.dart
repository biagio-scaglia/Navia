import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/navia_tokens.dart';
import '../../location/domain/location_models.dart';
import '../../location/presentation/location_controller.dart';
import '../../location/presentation/location_failure_messages.dart';
import '../../location/presentation/widgets/location_button.dart';
import '../domain/navia_map_controller.dart';
import 'map_providers.dart';
import 'widgets/map_attribution.dart';
import 'widgets/map_status_views.dart';
import 'widgets/map_top_bar.dart';
import 'widgets/map_zoom_controls.dart';
import 'widgets/navia_map_view.dart';

/// Main screen: a fullscreen map with minimal floating controls.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _edge = NaviaSpacing.lg;

  NaviaMapController? _map;
  late final AppLifecycleListener _lifecycle;

  LocationController get _location =>
      ref.read(locationControllerProvider.notifier);

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
    // A new style resets the location indicator.
    _showUserLocation(ref.read(locationControllerProvider).position);
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

  @override
  Widget build(BuildContext context) {
    ref.listen(locationControllerProvider, (previous, next) {
      if (next.position != previous?.position) {
        _showUserLocation(next.position);
      }
      final failure = next.failure;
      if (failure != null && previous?.status != LocationStatus.failed) {
        _showLocationFailure(failure);
      }
    });

    final theme = Theme.of(context);
    final load = ref.watch(mapLoadControllerProvider);
    final source = ref.watch(mapStyleSourceProvider);
    final locationStatus = ref.watch(
      locationControllerProvider.select((state) => state.status),
    );
    final hasPosition = ref.watch(
      locationControllerProvider.select((state) => state.position != null),
    );
    final safe = MediaQuery.paddingOf(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: NaviaMapView(
                key: ValueKey(load.attempt),
                styleUrl: source.styleUrlFor(theme.brightness),
                initialCamera: AppConfig.initialCamera,
                showUserLocation: hasPosition,
                controlsPadding: EdgeInsets.fromLTRB(
                  _edge + safe.left,
                  safe.top + _edge + MapTopBar.height + NaviaSpacing.md,
                  _edge + safe.right,
                  safe.bottom + _edge + NaviaSpacing.sm,
                ),
                onMapReady: _onMapReady,
                onStyleLoadStarted: ref
                    .read(mapLoadControllerProvider.notifier)
                    .loadStarted,
                onStyleLoaded: _onStyleLoaded,
              ),
            ),
            if (!load.hasLoaded && load.status == MapLoadStatus.loading)
              const Positioned.fill(child: MapLoadingView()),
            if (load.status == MapLoadStatus.failed)
              Positioned.fill(child: MapErrorView(onRetry: _retryMap)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(_edge),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: MapTopBar(
                          onOpenSettings: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.settings),
                        ),
                      ),
                    ),
                    if (load.hasLoaded) ...[
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MapZoomControls(
                              onZoomIn: () => _map?.zoomIn(),
                              onZoomOut: () => _map?.zoomOut(),
                            ),
                            const SizedBox(height: NaviaSpacing.md),
                            LocationButton(
                              status: locationStatus,
                              onPressed: _onLocationPressed,
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          // Leaves room for the native attribution button.
                          padding: const EdgeInsets.only(left: 32),
                          child: MapAttributionChip(source: source),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
