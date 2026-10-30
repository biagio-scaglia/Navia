import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_point.dart';
import '../../location/presentation/location_controller.dart';
import '../data/photon_geocoding_repository.dart';
import '../domain/place.dart';

enum SearchStatus { idle, loading, results, empty, failed }

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const [],
    this.failure,
  });

  final String query;
  final SearchStatus status;
  final List<Place> results;
  final ServiceFailure? failure;
}

/// Search-as-you-type with debouncing, caching and stale response handling.
///
/// Requests are sent only after [AppConfig.searchDebounce] without typing,
/// identical queries are served from memory, and responses for queries that
/// are no longer current are discarded.
class SearchController extends Notifier<SearchState> {
  static const _cacheSize = 30;

  // Map literals preserve insertion order, giving a simple FIFO cache.
  final _cache = <String, List<Place>>{};
  Timer? _debounce;
  int _generation = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void updateQuery(String text) {
    final query = text.trim();
    if (query == state.query && state.status != SearchStatus.failed) return;

    _debounce?.cancel();
    final generation = ++_generation;

    if (query.length < AppConfig.searchMinLength) {
      state = SearchState(query: query);
      return;
    }
    final cached = _cache[_key(query)];
    if (cached != null) {
      state = _resultsState(query, cached);
      return;
    }
    // Previous results stay visible while the next ones load.
    state = SearchState(
      query: query,
      status: SearchStatus.loading,
      results: state.results,
    );
    _debounce = Timer(
      ref.read(searchDebounceProvider),
      () => _search(query, generation),
    );
  }

  Future<void> retry() async {
    final query = state.query;
    if (query.length < AppConfig.searchMinLength) return;
    _debounce?.cancel();
    final generation = ++_generation;
    state = SearchState(query: query, status: SearchStatus.loading);
    await _search(query, generation);
  }

  Future<void> _search(String query, int generation) async {
    final repository = ref.read(geocodingRepositoryProvider);
    if (repository == null) {
      state = SearchState(
        query: query,
        status: SearchStatus.failed,
        failure: ServiceFailure.notConfigured,
      );
      return;
    }
    try {
      final results = await repository.search(
        query,
        near: ref.read(searchBiasProvider),
      );
      if (!ref.mounted || generation != _generation) return;
      _remember(query, results);
      state = _resultsState(query, results);
    } on ServiceException catch (error) {
      logServiceError('search', error);
      if (!ref.mounted || generation != _generation) return;
      state = SearchState(
        query: query,
        status: SearchStatus.failed,
        failure: error.failure,
      );
    }
  }

  void _remember(String query, List<Place> results) {
    _cache[_key(query)] = results;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
  }

  static String _key(String query) => query.toLowerCase();

  static SearchState _resultsState(String query, List<Place> results) =>
      SearchState(
        query: query,
        status: results.isEmpty ? SearchStatus.empty : SearchStatus.results,
        results: results,
      );
}

final searchControllerProvider =
    NotifierProvider.autoDispose<SearchController, SearchState>(
      SearchController.new,
    );

final searchDebounceProvider = Provider<Duration>(
  (ref) => AppConfig.searchDebounce,
);

/// Results are ranked around the user when known, otherwise around Bari.
final searchBiasProvider = Provider<GeoPoint>(
  (ref) =>
      ref.watch(
        locationControllerProvider.select((state) => state.position?.point),
      ) ??
      AppConfig.initialCamera.target,
);
