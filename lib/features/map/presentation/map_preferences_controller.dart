import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/map_preferences_repository.dart';
import '../domain/map_style_source.dart';
import 'map_providers.dart';

@immutable
class MapPreferences {
  const MapPreferences({
    this.appearance = MapAppearance.automatic,
    this.buildings3d = false,
  });

  final MapAppearance appearance;

  /// Tilted camera with extruded buildings.
  final bool buildings3d;

  @override
  bool operator ==(Object other) =>
      other is MapPreferences &&
      other.appearance == appearance &&
      other.buildings3d == buildings3d;

  @override
  int get hashCode => Object.hash(appearance, buildings3d);
}

/// Map appearance and 3D view, persisted locally.
class MapPreferencesController extends Notifier<MapPreferences> {
  MapPreferencesRepository get _repository =>
      ref.read(mapPreferencesRepositoryProvider);

  @override
  MapPreferences build() {
    final repository = ref.watch(mapPreferencesRepositoryProvider);
    final source = ref.watch(mapStyleSourceProvider);
    final stored = repository.loadAppearance();
    return MapPreferences(
      // A stored choice the provider no longer offers falls back safely.
      appearance: source.supports(stored) ? stored : MapAppearance.standard,
      buildings3d: repository.loadBuildings3d(),
    );
  }

  Future<void> setAppearance(MapAppearance appearance) async {
    if (appearance == state.appearance ||
        !ref.read(mapStyleSourceProvider).supports(appearance)) {
      return;
    }
    state = MapPreferences(
      appearance: appearance,
      buildings3d: state.buildings3d,
    );
    await _repository.saveAppearance(appearance);
  }

  Future<void> setBuildings3d(bool enabled) async {
    if (enabled == state.buildings3d) return;
    state = MapPreferences(appearance: state.appearance, buildings3d: enabled);
    await _repository.saveBuildings3d(enabled);
  }
}

final mapPreferencesProvider =
    NotifierProvider<MapPreferencesController, MapPreferences>(
      MapPreferencesController.new,
    );
