import '../../../shared/models/geo_bounds.dart';
import 'poi.dart';
import 'poi_category.dart';

/// Source of OpenStreetMap points of interest.
abstract interface class PlacesRepository {
  /// At most this many places are returned for one area, to keep the map
  /// readable and responses small.
  static const maxResults = 150;

  /// Places of [category] inside [bounds].
  ///
  /// Throws a `ServiceException` when the service fails.
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds);
}
