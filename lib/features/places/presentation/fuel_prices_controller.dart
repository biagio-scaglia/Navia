import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_bounds.dart';
import '../data/fuel_prices_store.dart';
import '../data/place_data_client.dart';
import '../domain/fuel.dart';
import '../domain/places_repository.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';

@immutable
class FuelPricesState {
  const FuelPricesState({this.info, this.progress, this.failure});

  /// The installed dataset, if any.
  final FuelDataInfo? info;

  /// Download progress from 0 to 1 (null value while unknown); absent when
  /// no download is running.
  final double? progress;
  final ServiceFailure? failure;

  bool get downloading => progress != null;
}

/// Downloads, refreshes and deletes the daily fuel prices, only on request.
class FuelPricesController extends Notifier<FuelPricesState> {
  bool _cancelled = false;

  @override
  FuelPricesState build() =>
      FuelPricesState(info: ref.watch(fuelPricesStoreProvider)?.info());

  Future<void> download() async {
    final store = ref.read(fuelPricesStoreProvider);
    if (store == null || state.downloading) return;
    _cancelled = false;
    state = FuelPricesState(info: state.info, progress: 0);
    try {
      final info = await store.download(
        userAgent: ref.read(jsonHttpClientProvider).userAgent,
        isCancelled: () => _cancelled,
        onProgress: (received, total) {
          if (!ref.mounted || total == null || total == 0) return;
          state = FuelPricesState(info: state.info, progress: received / total);
        },
      );
      if (ref.mounted) state = FuelPricesState(info: info);
    } on DownloadCancelled {
      if (ref.mounted) state = FuelPricesState(info: state.info);
    } on ServiceException catch (error) {
      logServiceError('fuel prices', error);
      if (ref.mounted) {
        state = FuelPricesState(info: state.info, failure: error.failure);
      }
    }
  }

  void cancel() => _cancelled = true;

  Future<void> delete() async {
    await ref.read(fuelPricesStoreProvider)?.delete();
    if (ref.mounted) state = const FuelPricesState();
  }
}

final fuelPricesProvider =
    NotifierProvider<FuelPricesController, FuelPricesState>(
      FuelPricesController.new,
    );

/// The stations of the installed dataset, loaded once per installation.
final fuelStationsProvider = FutureProvider<List<FuelStation>>((ref) async {
  final installed = ref.watch(fuelPricesProvider.select((s) => s.info));
  final store = ref.watch(fuelPricesStoreProvider);
  if (installed == null || store == null) return const [];
  return store.load();
});

/// Adds Ministry prices to the fuel stations found by [inner].
class FuelPricedPlacesRepository implements PlacesRepository {
  FuelPricedPlacesRepository(this.inner, this.stations);

  final PlacesRepository inner;
  final Future<List<FuelStation>> Function() stations;

  @override
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds) async {
    final places = await inner.fetch(category, bounds);
    if (category != PoiCategory.fuel) return places;
    return FuelPriceMatcher.annotate(places, await stations());
  }
}
