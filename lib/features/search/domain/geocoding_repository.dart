import '../../../shared/models/geo_point.dart';
import 'place.dart';

/// Forward geocoding: from free text to places.
abstract interface class GeocodingRepository {
  /// Places matching [query], ranked by relevance and biased towards [near].
  ///
  /// Throws `ServiceException` on failure.
  Future<List<Place>> search(String query, {GeoPoint? near});
}
