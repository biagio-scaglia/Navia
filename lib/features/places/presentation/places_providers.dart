import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_first_places_repository.dart';
import '../data/offline_places_store.dart';
import '../data/overpass_places_repository.dart';
import '../data/place_data_client.dart';
import '../domain/places_repository.dart';
import 'fuel_prices_controller.dart';
import 'offline_places_controller.dart';

/// Where discovery reads places from: downloaded regions first, then the
/// online service. Null when neither is configured.
final placesRepositoryProvider = Provider<PlacesRepository?>((ref) {
  final online = ref.watch(onlinePlacesRepositoryProvider);
  final offlineAvailable = ref.watch(placeDataClientProvider) != null;
  final installed = ref.watch(installedRegionsProvider);
  if (online == null && !offlineAvailable && installed.isEmpty) return null;
  final places = LocalFirstPlacesRepository(
    store: ref.watch(offlinePlacesStoreProvider),
    installed: installed,
    online: online,
  );
  // Fuel stations get the Ministry prices when they are downloaded.
  return FuelPricedPlacesRepository(
    places,
    () => ref.read(fuelStationsProvider.future),
  );
});
