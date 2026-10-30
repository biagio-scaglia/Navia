import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local key-value storage for user preferences.
///
/// The instance is loaded once during bootstrap and injected through a
/// provider override, so reads are synchronous everywhere else.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden during bootstrap.',
  ),
);
