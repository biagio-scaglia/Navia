import '../../../core/errors/app_failure.dart';
import '../../../shared/models/geo_bounds.dart';
import '../domain/place_region.dart';
import '../domain/places_repository.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';
import 'offline_places_store.dart';

/// Serves places from downloaded regions when they cover the view, and
/// from the online service otherwise.
///
/// Local answers need no network and send nothing anywhere. A region
/// covers the view when its bounding box contains the view's center; near
/// region borders the view may also show places of a neighboring region if
/// it is installed too.
class LocalFirstPlacesRepository implements PlacesRepository {
  LocalFirstPlacesRepository({
    required this.store,
    required this.installed,
    this.online,
  });

  final OfflinePlacesStore store;
  final List<InstalledRegion> installed;

  /// Used outside the installed regions; null for offline-only use.
  final PlacesRepository? online;

  bool covers(GeoBounds bounds) => installed.any(
    (region) => region.region.bounds.containsPoint(bounds.center),
  );

  @override
  Future<List<Poi>> fetch(PoiCategory category, GeoBounds bounds) {
    if (covers(bounds)) {
      return store.query(
        category,
        bounds,
        installed,
        limit: PlacesRepository.maxResults,
      );
    }
    final online = this.online;
    if (online == null) {
      throw const ServiceException(ServiceFailure.notConfigured);
    }
    return online.fetch(category, bounds);
  }
}
