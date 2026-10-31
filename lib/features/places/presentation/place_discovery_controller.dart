import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_bounds.dart';
import '../data/places_cache.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';
import 'fuel_prices_controller.dart';
import 'offline_places_controller.dart';
import 'places_providers.dart';

enum DiscoveryStatus {
  /// No category selected.
  idle,

  /// The visible area is too large to list places: zoom in.
  zoomIn,
  loading,
  ready,
  failed,
}

@immutable
class PlaceDiscoveryState {
  const PlaceDiscoveryState({
    this.category,
    this.status = DiscoveryStatus.idle,
    this.places = const [],
    this.failure,
  });

  final PoiCategory? category;
  final DiscoveryStatus status;

  /// Places of [category] around the visible area.
  final List<Poi> places;

  final ServiceFailure? failure;
}

/// Lists OpenStreetMap places of one category around the visible map area.
///
/// Requests are made only while a category is selected, after the camera
/// has been idle for [placesDebounceProvider], and when the zoom level shows
/// a small enough area. The queried area is the view plus a margin, snapped
/// to a grid, so small pans are served from the previous answer or from
/// [PlacesCache] without any request. Responses for an outdated view or
/// category are ignored.
class PlaceDiscoveryController extends Notifier<PlaceDiscoveryState> {
  /// Areas are rounded to this grid, in degrees (about 1 km).
  static const _grid = 0.01;

  /// Margin added around the view before snapping, as a fraction.
  static const _margin = 0.25;

  /// Largest area that is queried, in degrees of latitude or longitude.
  static const _maxSpan = 0.12;

  Timer? _debounce;
  int _generation = 0;
  GeoBounds? _view;
  double _zoom = 0;

  /// The area whose places are currently shown.
  GeoBounds? _shownArea;

  /// The request in flight, to avoid sending the same one twice.
  (PoiCategory, GeoBounds)? _pending;

  @override
  PlaceDiscoveryState build() {
    ref
      ..onDispose(() => _debounce?.cancel())
      // A region was downloaded or deleted: answers may now differ.
      ..listen(installedRegionsProvider, (_, _) => _reloadAfterSourceChange())
      ..listen(
        fuelPricesProvider.select((s) => s.info),
        (_, _) => _reloadAfterSourceChange(),
      );
    return const PlaceDiscoveryState();
  }

  void _reloadAfterSourceChange() {
    ref.read(placesCacheProvider).clear();
    _generation++;
    _shownArea = null;
    _pending = null;
    if (state.category != null) unawaited(_load());
  }

  bool get isAvailable => ref.read(placesRepositoryProvider) != null;

  /// Selects [category], or clears discovery when null or already selected.
  void toggle(PoiCategory category) =>
      select(state.category == category ? null : category);

  void select(PoiCategory? category) {
    _debounce?.cancel();
    _generation++;
    _shownArea = null;
    _pending = null;
    if (category == null) {
      state = const PlaceDiscoveryState();
      return;
    }
    state = PlaceDiscoveryState(
      category: category,
      status: DiscoveryStatus.loading,
    );
    unawaited(_load());
  }

  /// Reports the area shown once the camera stops moving.
  void viewportChanged(GeoBounds visible, double zoom) {
    _view = visible;
    _zoom = zoom;
    if (state.category == null) return;
    _debounce?.cancel();
    _debounce = Timer(ref.read(placesDebounceProvider), _load);
  }

  Future<void> retry() => _load();

  Future<void> _load() async {
    final category = state.category;
    final view = _view;
    final repository = ref.read(placesRepositoryProvider);
    if (category == null || view == null || repository == null) return;

    if (_zoom < AppConfig.placesMinZoom ||
        view.latitudeSpan > _maxSpan ||
        view.longitudeSpan > _maxSpan) {
      _generation++;
      _pending = null;
      state = PlaceDiscoveryState(
        category: category,
        status: DiscoveryStatus.zoomIn,
        places: state.places,
      );
      return;
    }

    final shown = _shownArea;
    if (shown != null &&
        shown.containsBounds(view) &&
        state.status == DiscoveryStatus.ready) {
      return;
    }

    final cache = ref.read(placesCacheProvider);
    final cached = cache.covering(category, view);
    if (cached != null) {
      _generation++;
      _pending = null;
      _show(category, cached.area, cached.places);
      return;
    }

    final area = view.expandedBy(_margin).snappedTo(_grid);
    if (_pending == (category, area)) return;
    final generation = ++_generation;
    _pending = (category, area);
    state = PlaceDiscoveryState(
      category: category,
      status: DiscoveryStatus.loading,
      places: state.places,
    );

    try {
      final places = await repository.fetch(category, area);
      if (!ref.mounted) return;
      cache.put(category, area, places);
      if (generation != _generation) return;
      _pending = null;
      _show(category, area, places);
    } on ServiceException catch (error) {
      logServiceError('places', error);
      if (!ref.mounted || generation != _generation) return;
      _pending = null;
      state = PlaceDiscoveryState(
        category: category,
        status: DiscoveryStatus.failed,
        places: state.places,
        failure: error.failure,
      );
    }
  }

  void _show(PoiCategory category, GeoBounds area, List<Poi> places) {
    _shownArea = area;
    state = PlaceDiscoveryState(
      category: category,
      status: DiscoveryStatus.ready,
      places: places,
    );
  }

  /// A shown place by its [OsmRef.key], e.g. for a tap on the map.
  Poi? placeByKey(String key) {
    for (final place in state.places) {
      if (place.ref.key == key) return place;
    }
    return null;
  }
}

final placeDiscoveryProvider =
    NotifierProvider<PlaceDiscoveryController, PlaceDiscoveryState>(
      PlaceDiscoveryController.new,
    );

/// Wait after the camera stops before querying, overridable in tests.
final placesDebounceProvider = Provider<Duration>(
  (ref) => AppConfig.placesDebounce,
);
