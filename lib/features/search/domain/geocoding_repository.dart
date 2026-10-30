import '../../../shared/models/geo_point.dart';
import 'place.dart';

/// Geocoding: from free text to places, and from coordinates to addresses.
abstract interface class GeocodingRepository {
  /// Places matching [query], ranked by relevance and biased towards [near].
  ///
  /// Throws `ServiceException` on failure.
  Future<List<Place>> search(String query, {GeoPoint? near});

  /// The address or place closest to [point], or null if there is none.
  ///
  /// Throws `ServiceException` on failure.
  Future<Place?> reverse(GeoPoint point);
}
