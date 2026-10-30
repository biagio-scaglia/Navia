import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/geo_bounds.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';

/// In-memory cache of place results per category and area.
///
/// Entries expire after [maxAge], so edits made on OpenStreetMap show up in
/// a later session, and the least recently used entries are dropped beyond
/// [capacity] to bound memory use. Nothing is written to disk.
class PlacesCache {
  PlacesCache({
    this.capacity = 24,
    this.maxAge = const Duration(minutes: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int capacity;
  final Duration maxAge;
  final DateTime Function() _clock;

  // Map literals keep insertion order, which tracks recent use here.
  final _entries =
      <(PoiCategory, GeoBounds), ({DateTime at, List<Poi> places})>{};

  List<Poi>? get(PoiCategory category, GeoBounds area) {
    final key = (category, area);
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (_clock().difference(entry.at) > maxAge) return null;
    // Re-inserted as the most recently used.
    _entries[key] = entry;
    return entry.places;
  }

  /// A fresh cached area of [category] that fully covers [bounds].
  ({GeoBounds area, List<Poi> places})? covering(
    PoiCategory category,
    GeoBounds bounds,
  ) {
    for (final MapEntry(:key, :value) in _entries.entries.toList().reversed) {
      if (key.$1 != category || !key.$2.containsBounds(bounds)) continue;
      if (_clock().difference(value.at) > maxAge) continue;
      return (area: key.$2, places: value.places);
    }
    return null;
  }

  void put(PoiCategory category, GeoBounds area, List<Poi> places) {
    final key = (category, area);
    _entries
      ..remove(key)
      ..[key] = (at: _clock(), places: List.unmodifiable(places));
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}

final placesCacheProvider = Provider<PlacesCache>((ref) => PlacesCache());
