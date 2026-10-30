import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import '../domain/favorite.dart';

/// Stores favorites on the device as a JSON list. Nothing leaves the device.
///
/// A small list of places does not justify a database; the format is
/// versioned in the key so it can be migrated if favorites grow richer.
class FavoritesRepository {
  FavoritesRepository(this._preferences);

  static const storageKey = 'favorites.v1';

  final SharedPreferences _preferences;

  List<Favorite> load() {
    final raw = _preferences.getString(storageKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final entry in decoded) ?Favorite.tryParse(entry)];
    } on FormatException catch (error) {
      // Corrupted storage must not crash the app; start over.
      debugPrint('[favorites] could not read stored favorites: $error');
      return const [];
    }
  }

  Future<void> save(List<Favorite> favorites) => _preferences.setString(
    storageKey,
    jsonEncode([for (final favorite in favorites) favorite.toJson()]),
  );
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(sharedPreferencesProvider)),
);
