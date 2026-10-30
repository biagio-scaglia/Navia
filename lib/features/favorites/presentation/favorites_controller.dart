import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/geo_point.dart';
import '../../places/domain/poi.dart';
import '../data/favorites_repository.dart';
import '../domain/favorite.dart';

enum FavoriteAddResult { added, duplicate, invalidName }

/// Saved places, newest first, persisted locally.
class FavoritesController extends Notifier<List<Favorite>> {
  /// Points closer than this are considered the same place.
  static const duplicateRadiusMeters = 15.0;

  static const maxNameLength = 60;

  FavoritesRepository get _repository => ref.read(favoritesRepositoryProvider);

  @override
  List<Favorite> build() => ref.watch(favoritesRepositoryProvider).load();

  /// The saved favorite for the same OpenStreetMap object as [osmRef], or
  /// at (or very near) [point], if any.
  Favorite? findExisting(GeoPoint point, {OsmRef? osmRef}) {
    for (final favorite in state) {
      if (osmRef != null && favorite.osmRef == osmRef) return favorite;
    }
    for (final favorite in state) {
      if (favorite.point.distanceTo(point) <= duplicateRadiusMeters) {
        return favorite;
      }
    }
    return null;
  }

  Future<FavoriteAddResult> add(
    String name,
    GeoPoint point, {
    OsmRef? osmRef,
    String? category,
    String? address,
  }) async {
    final cleaned = _clean(name);
    if (cleaned == null) return FavoriteAddResult.invalidName;
    if (findExisting(point, osmRef: osmRef) != null) {
      return FavoriteAddResult.duplicate;
    }
    final now = DateTime.now();
    final favorite = Favorite(
      id: _uniqueId(now),
      name: cleaned,
      point: point,
      createdAt: now,
      osmRef: osmRef,
      category: category,
      address: address,
    );
    await _update([favorite, ...state]);
    return FavoriteAddResult.added;
  }

  Future<bool> rename(String id, String name) async {
    final cleaned = _clean(name);
    if (cleaned == null) return false;
    await _update([
      for (final favorite in state)
        favorite.id == id ? favorite.copyWith(name: cleaned) : favorite,
    ]);
    return true;
  }

  /// Removes a favorite and returns it, so that the removal can be undone.
  Future<Favorite?> remove(String id) async {
    final index = state.indexWhere((favorite) => favorite.id == id);
    if (index < 0) return null;
    final removed = state[index];
    await _update([...state]..removeAt(index));
    return removed;
  }

  /// Puts back a favorite returned by [remove].
  Future<void> restore(Favorite favorite) async {
    if (state.any((f) => f.id == favorite.id)) return;
    final restored = [...state, favorite]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _update(restored);
  }

  Future<void> _update(List<Favorite> favorites) async {
    state = List.unmodifiable(favorites);
    await _repository.save(state);
  }

  /// Time-based id, bumped when the clock resolution (coarse on some
  /// platforms) would produce the same value twice.
  String _uniqueId(DateTime now) {
    var candidate = now.microsecondsSinceEpoch;
    final taken = {for (final favorite in state) favorite.id};
    while (taken.contains('$candidate')) {
      candidate++;
    }
    return '$candidate';
  }

  static String? _clean(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return null;
    return trimmed.length > maxNameLength
        ? trimmed.substring(0, maxNameLength)
        : trimmed;
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, List<Favorite>>(
  FavoritesController.new,
);
