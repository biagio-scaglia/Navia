import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../core/network/verified_download.dart';
import '../../../shared/models/geo_point.dart';
import '../../map/domain/map_style_source.dart';
import '../../map/presentation/map_providers.dart';
import '../data/map_data_client.dart';
import '../data/offline_map_style.dart';
import '../data/offline_maps_store.dart';
import '../domain/map_region.dart';

enum MapCatalogStatus { idle, loading, ready, failed }

@immutable
class OfflineMapsState {
  const OfflineMapsState({
    this.catalogStatus = MapCatalogStatus.idle,
    this.catalog = const [],
    this.installed = const [],
    this.progress = const {},
    this.failures = const {},
    this.catalogFailure,
  });

  final MapCatalogStatus catalogStatus;

  /// Regions offered for download.
  final List<MapRegion> catalog;

  /// Regions stored on the device.
  final List<InstalledMapRegion> installed;

  /// Downloads in progress by region id, from 0 to 1; null while the map
  /// is being installed.
  final Map<String, double?> progress;

  /// The last failed download of each region.
  final Map<String, ServiceFailure> failures;

  final ServiceFailure? catalogFailure;

  InstalledMapRegion? installedRegion(String id) {
    for (final region in installed) {
      if (region.region.id == id) return region;
    }
    return null;
  }

  OfflineMapsState copyWith({
    MapCatalogStatus? catalogStatus,
    List<MapRegion>? catalog,
    List<InstalledMapRegion>? installed,
    Map<String, double?>? progress,
    Map<String, ServiceFailure>? failures,
    ServiceFailure? Function()? catalogFailure,
  }) => OfflineMapsState(
    catalogStatus: catalogStatus ?? this.catalogStatus,
    catalog: catalog ?? this.catalog,
    installed: installed ?? this.installed,
    progress: progress ?? this.progress,
    failures: failures ?? this.failures,
    catalogFailure: catalogFailure == null
        ? this.catalogFailure
        : catalogFailure(),
  );
}

/// Downloads, stores and deletes the maps of whole regions.
///
/// Nothing is downloaded without an explicit request from the user, who
/// can cancel a download or delete stored maps at any time.
class OfflineMapsController extends Notifier<OfflineMapsState> {
  final _cancelled = <String>{};

  OfflineMapsStore get _store => ref.read(offlineMapsStoreProvider);

  @override
  OfflineMapsState build() => OfflineMapsState(
    installed: ref.watch(offlineMapsStoreProvider).installed(),
  );

  bool get isAvailable => ref.read(mapDataClientProvider) != null;

  Future<void> loadCatalog() async {
    final client = ref.read(mapDataClientProvider);
    if (client == null || state.catalogStatus == MapCatalogStatus.loading) {
      return;
    }
    state = state.copyWith(
      catalogStatus: MapCatalogStatus.loading,
      catalogFailure: () => null,
    );
    try {
      final catalog = await client.catalog();
      if (!ref.mounted) return;
      state = state.copyWith(
        catalogStatus: MapCatalogStatus.ready,
        catalog: catalog,
      );
    } on ServiceException catch (error) {
      logServiceError('map data', error);
      if (!ref.mounted) return;
      state = state.copyWith(
        catalogStatus: MapCatalogStatus.failed,
        catalogFailure: () => error.failure,
      );
    }
  }

  Future<void> download(MapRegion region) async {
    final client = ref.read(mapDataClientProvider);
    if (client == null || state.progress.containsKey(region.id)) return;
    _cancelled.remove(region.id);
    _setProgress(region.id, 0);
    state = state.copyWith(failures: {...state.failures}..remove(region.id));

    final file = File('${_store.downloads.path}/${region.id}.pmtiles');
    var lastStep = 0;
    try {
      await client.download(
        region,
        file,
        isCancelled: () => _cancelled.contains(region.id),
        onProgress: (received, total) {
          // One update per percent keeps rebuilds cheap.
          final step = received * 100 ~/ total;
          if (step == lastStep || !ref.mounted) return;
          lastStep = step;
          _setProgress(region.id, step / 100);
        },
      );
      if (!ref.mounted) return;
      _setProgress(region.id, null);
      final installed = await _store.install(region, file);
      if (!ref.mounted) return;
      state = state.copyWith(
        installed: [
          for (final other in state.installed)
            if (other.region.id != region.id) other,
          installed,
        ]..sort((a, b) => a.region.name.compareTo(b.region.name)),
      );
    } on DownloadCancelled {
      // The partial file was deleted by the client.
    } on ServiceException catch (error) {
      logServiceError('map data', error);
      if (ref.mounted) {
        state = state.copyWith(
          failures: {...state.failures, region.id: error.failure},
        );
      }
    } on FileSystemException catch (error) {
      // Most often a full storage.
      logServiceError('map data', error);
      if (file.existsSync()) await file.delete();
      if (ref.mounted) {
        state = state.copyWith(
          failures: {...state.failures, region.id: ServiceFailure.unavailable},
        );
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(
          progress: {...state.progress}..remove(region.id),
        );
      }
    }
  }

  void cancel(String regionId) => _cancelled.add(regionId);

  Future<void> delete(String regionId) async {
    await _store.delete(regionId);
    if (!ref.mounted) return;
    state = state.copyWith(
      installed: [
        for (final region in state.installed)
          if (region.region.id != regionId) region,
      ],
    );
  }

  void _setProgress(String id, double? value) {
    state = state.copyWith(progress: {...state.progress, id: value});
  }
}

final offlineMapsProvider =
    NotifierProvider<OfflineMapsController, OfflineMapsState>(
      OfflineMapsController.new,
    );

/// Regions whose map is stored on the device; changes only when one is
/// added or removed.
final installedMapRegionsProvider = Provider<List<InstalledMapRegion>>(
  (ref) => ref.watch(offlineMapsProvider.select((s) => s.installed)),
);

/// The installed regions to draw: all of them while the map is centered
/// inside one, otherwise none, so the online map is used.
///
/// The map reports its center when the camera stops; the online map is
/// therefore kept outside the downloaded areas, and the downloaded one is
/// used inside them even with a connection, which is faster and sends
/// nothing to the tile server.
class OfflineMapCoverage extends Notifier<List<InstalledMapRegion>> {
  GeoPoint _center = AppConfig.initialCamera.target;

  @override
  List<InstalledMapRegion> build() =>
      _covering(ref.watch(installedMapRegionsProvider));

  void centerChanged(GeoPoint center) {
    _center = center;
    final regions = _covering(ref.read(installedMapRegionsProvider));
    if (!listEquals(regions, state)) state = regions;
  }

  List<InstalledMapRegion> _covering(List<InstalledMapRegion> installed) =>
      installed.any((r) => r.region.bounds.containsPoint(_center))
      ? installed
      : const [];
}

final offlineMapCoverageProvider =
    NotifierProvider<OfflineMapCoverage, List<InstalledMapRegion>>(
      OfflineMapCoverage.new,
    );

/// Bundled style documents, read once from the app's assets.
final offlineStyleTemplateProvider =
    FutureProvider.family<Map<String, Object?>, String>(
      (ref, asset) async =>
          jsonDecode(await rootBundle.loadString(asset))
              as Map<String, Object?>,
    );

/// The style document drawing [style] from the downloaded maps, or null
/// when the online style must be used: outside the downloaded areas, for
/// a style without a bundled copy, or while the copy is being read.
final offlineMapStyleProvider = Provider.family<String?, MapStyleId>((
  ref,
  style,
) {
  final regions = ref.watch(offlineMapCoverageProvider);
  if (regions.isEmpty) return null;
  final source = ref.watch(mapStyleSourceProvider);
  final asset = source.offlineStyles[style];
  final sourceId = source.offlineSourceId;
  if (asset == null || sourceId == null) return null;
  final template = ref.watch(offlineStyleTemplateProvider(asset)).value;
  if (template == null) return null;
  return OfflineMapStyle.build(template, sourceId: sourceId, regions: regions);
});
