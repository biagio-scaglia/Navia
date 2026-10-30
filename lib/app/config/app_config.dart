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

  /// Photon geocoder used for search. An empty value disables search.
  ///
  /// The public komoot instance allows fair, low-volume use only; production
  /// deployments should point this to a self-hosted Photon instance with
  /// `--dart-define=NAVIA_PHOTON_URL=https://example.org`.
  static const geocodingUrl = String.fromEnvironment(
    'NAVIA_PHOTON_URL',
    defaultValue: 'https://photon.komoot.io',
  );

  /// Wait after the last keystroke before searching, to limit requests.
  static const searchDebounce = Duration(milliseconds: 450);
  static const searchMinLength = 3;

  /// OSRM endpoints for each travel mode. An empty value disables the mode.
  ///
  /// The defaults are the FOSSGIS servers (routing.openstreetmap.de), whose
  /// policy allows at most one request per second, requires an identifying
  /// User-Agent and OpenStreetMap attribution, and forbids heavy usage.
  static const routingCarUrl = String.fromEnvironment(
    'NAVIA_OSRM_CAR_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-car',
  );
  static const routingBikeUrl = String.fromEnvironment(
    'NAVIA_OSRM_BIKE_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-bike',
  );
  static const routingFootUrl = String.fromEnvironment(
    'NAVIA_OSRM_FOOT_URL',
    defaultValue: 'https://routing.openstreetmap.de/routed-foot',
  );

  /// Minimum interval between routing requests (FOSSGIS policy).
  static const routingMinInterval = Duration(seconds: 1);

  static const fixTheMapUrl = 'https://www.openstreetmap.org/fixthemap';

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
