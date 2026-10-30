import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../data/offline_places_store.dart';
import '../data/place_data_client.dart';
import '../domain/place_region.dart';

enum CatalogStatus { idle, loading, ready, failed }

@immutable
class OfflinePlacesState {
  const OfflinePlacesState({
    this.catalogStatus = CatalogStatus.idle,
    this.catalog = const [],
    this.installed = const [],
    this.progress = const {},
    this.failures = const {},
    this.catalogFailure,
  });

  final CatalogStatus catalogStatus;

  /// Regions offered for download.
  final List<PlaceRegion> catalog;

  /// Regions stored on the device.
  final List<InstalledRegion> installed;

  /// Downloads in progress by region id, from 0 to 1; null while the data
  /// is being installed.
  final Map<String, double?> progress;

  /// The last failed download of each region.
  final Map<String, ServiceFailure> failures;

  final ServiceFailure? catalogFailure;

  InstalledRegion? installedRegion(String id) {
    for (final region in installed) {
      if (region.region.id == id) return region;
    }
    return null;
  }

  OfflinePlacesState copyWith({
    CatalogStatus? catalogStatus,
    List<PlaceRegion>? catalog,
    List<InstalledRegion>? installed,
    Map<String, double?>? progress,
    Map<String, ServiceFailure>? failures,
    ServiceFailure? Function()? catalogFailure,
  }) => OfflinePlacesState(
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

/// Downloads, stores and deletes the place datasets of whole regions.
///
/// Nothing is downloaded without an explicit request from the user, who
/// can cancel a download or delete stored data at any time.
class OfflinePlacesController extends Notifier<OfflinePlacesState> {
  final _cancelled = <String>{};

  OfflinePlacesStore get _store => ref.read(offlinePlacesStoreProvider);

  @override
  OfflinePlacesState build() => OfflinePlacesState(
    installed: ref.watch(offlinePlacesStoreProvider).installed(),
  );

  bool get isAvailable => ref.read(placeDataClientProvider) != null;

  Future<void> loadCatalog() async {
    final client = ref.read(placeDataClientProvider);
    if (client == null || state.catalogStatus == CatalogStatus.loading) return;
    state = state.copyWith(
      catalogStatus: CatalogStatus.loading,
      catalogFailure: () => null,
    );
    try {
      final catalog = await client.catalog();
      if (!ref.mounted) return;
      state = state.copyWith(
        catalogStatus: CatalogStatus.ready,
        catalog: catalog,
      );
    } on ServiceException catch (error) {
      logServiceError('places data', error);
      if (!ref.mounted) return;
      state = state.copyWith(
        catalogStatus: CatalogStatus.failed,
        catalogFailure: () => error.failure,
      );
    }
  }

  Future<void> download(PlaceRegion region) async {
    final client = ref.read(placeDataClientProvider);
    if (client == null || state.progress.containsKey(region.id)) return;
    _cancelled.remove(region.id);
    _setProgress(region.id, 0);
    state = state.copyWith(failures: {...state.failures}..remove(region.id));

    final file = File('${_store.downloads.path}/${region.id}.jsonl.gz');
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
      logServiceError('places data', error);
      if (ref.mounted) {
        state = state.copyWith(
          failures: {...state.failures, region.id: error.failure},
        );
      }
    } on FileSystemException catch (error) {
      logServiceError('places data', error);
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

final offlinePlacesProvider =
    NotifierProvider<OfflinePlacesController, OfflinePlacesState>(
      OfflinePlacesController.new,
    );

/// Regions stored on the device; changes only when one is added or removed.
final installedRegionsProvider = Provider<List<InstalledRegion>>(
  (ref) => ref.watch(offlinePlacesProvider.select((s) => s.installed)),
);
