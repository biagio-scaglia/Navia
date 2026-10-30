import '../../features/map/domain/map_camera.dart';
import '../../features/map/domain/map_style_source.dart';
import '../../shared/models/geo_point.dart';

/// Central, compile-time application configuration.
abstract final class AppConfig {
  static const appName = 'Navia';
  static const sourceCodeUrl = 'https://github.com/biagio-scaglia/Navia';

  /// Bari, Italy: the first area Navia is built and tested for.
  static const initialCamera = MapCamera(
    target: GeoPoint(latitude: 41.1171, longitude: 16.8719),
    zoom: 13.5,
  );

  /// Zoom used when centering the map on the user.
  static const userLocationZoom = 16.0;

  static const minZoom = 2.0;
  static const maxZoom = 19.0;

  /// After this delay without a loaded style, the map shows an error state.
  static const mapLoadTimeout = Duration(seconds: 20);

  static const mapStyleSource = openFreeMap;

  /// OpenFreeMap: free, no API key, no registration, OpenStreetMap data.
  /// See https://openfreemap.org for its terms of use.
  static const openFreeMap = MapStyleSource(
    name: 'OpenFreeMap',
    lightStyleUrl: 'https://tiles.openfreemap.org/styles/liberty',
    darkStyleUrl: 'https://tiles.openfreemap.org/styles/dark',
    attributions: [
      MapAttribution(
        label: '© OpenStreetMap contributors',
        url: 'https://www.openstreetmap.org/copyright',
      ),
      MapAttribution(
        label: '© OpenMapTiles',
        url: 'https://www.openmaptiles.org/',
      ),
      MapAttribution(label: 'OpenFreeMap', url: 'https://openfreemap.org/'),
    ],
  );
}
