import '../../../shared/models/geo_point.dart';
import 'navigation_models.dart';

/// Calculates routes between two points.
///
/// Online services (OSRM today, Valhalla or GraphHopper later) and a future
/// on-device router implement this same interface.
abstract interface class RoutingRepository {
  /// Travel modes this provider can route. Unsupported modes are hidden.
  Set<TravelMode> get supportedModes;

  /// Throws `ServiceException` on failure, with `ServiceFailure.noResult`
  /// when no route connects the two points.
  Future<NavRoute> route({
    required GeoPoint origin,
    required GeoPoint destination,
    required TravelMode mode,
  });
}
