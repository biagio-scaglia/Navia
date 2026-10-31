import '../../features/map/domain/map_camera.dart';
import '../../features/map/domain/map_style_source.dart';
import '../../shared/models/geo_point.dart';

/// Central, compile-time application configuration.
abstract final class AppConfig {
  static const appName = 'Navia';
  static const sourceCodeUrl = 'https://github.com/biagio-scaglia/Navia';
  static const privacyPolicyUrl = '$sourceCodeUrl/blob/main/PRIVACY.md';

  /// Bari, Italy: the first area Navia is built and tested for.
  static const initialCamera = MapCamera(
    target: GeoPoint(latitude: 41.1171, longitude: 16.8719),
    zoom: 14,
  );

  /// Camera pitch used by the 3D view, in degrees.
  static const pitch3d = 60.0;

  /// Zoom used when centering the map on the user.
  static const userLocationZoom = 16.0;

  /// Zoom of the camera following the user during guidance.
  static const guidanceZoom = 17.0;

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

  /// Overpass API endpoint for place discovery. An empty value disables it.
  ///
  /// The public overpass-api.de server is shared community infrastructure
  /// (guideline: under 10,000 queries and 1 GB per day per user). Navia
  /// queries it only after the user picks a category, for the visible area,
  /// and caches results. A wider deployment should use its own instance:
  /// `--dart-define=NAVIA_OVERPASS_URL=https://example.org/api/interpreter`.
  static const placesUrl = String.fromEnvironment(
    'NAVIA_OVERPASS_URL',
    defaultValue: 'https://overpass-api.de/api/interpreter',
  );

  /// Client-side limit of a place request. The query asks the server to
  /// stop after 15 seconds, but a busy public server first keeps requests
  /// in its queue: answers taking 40 seconds were measured in October 2026.
  static const placesRequestTimeout = Duration(seconds: 60);

  /// Waits before retrying when the server reports it is at capacity, with
  /// the exponential backoff the public servers ask for.
  static const placesRetryDelays = [Duration(seconds: 3), Duration(seconds: 8)];

  /// Where the downloadable place datasets and their `manifest.json`
  /// catalog are published: release assets of this repository, rebuilt
  /// monthly from OpenStreetMap extracts by the `Places data` workflow. An
  /// empty value disables offline place data.
  static const placesDataUrl = String.fromEnvironment(
    'NAVIA_PLACES_DATA_URL',
    defaultValue: '$sourceCodeUrl/releases/download/places-data',
  );

  /// Minimum interval between place requests.
  static const placesMinInterval = Duration(seconds: 2);

  /// Below this zoom the visible area is too large to list places.
  static const placesMinZoom = 13.0;

  /// Wait after the camera stops before querying places.
  static const placesDebounce = Duration(milliseconds: 700);

  static const fixTheMapUrl = 'https://www.openstreetmap.org/fixthemap';

  static const mapStyleSource = openFreeMap;

  /// OpenFreeMap: free (also for commercial use), no request limits, no
  /// API key, no registration; attribution required. Vector tiles follow the
  /// OpenMapTiles schema, built from OpenStreetMap data, worldwide.
  /// See https://openfreemap.org and its Terms of Service.
  static const openFreeMap = MapStyleSource(
    name: 'OpenFreeMap',
    styleUrls: {
      // Liberty: streets, buildings (with real heights), POIs, parks, water.
      MapStyleId.standard: 'https://tiles.openfreemap.org/styles/liberty',
      MapStyleId.vivid: 'https://tiles.openfreemap.org/styles/bright',
      // Navia Essenziale: Liberty with a muted palette, keeping POIs and
      // building heights (tool/map_styles/build_essential_style.py).
      MapStyleId.minimal: 'assets/map_styles/navia_essential.json',
      // Navia Notte: Liberty recolored for night use, bundled with the app
      // (tool/map_styles/build_night_style.py), same OpenFreeMap tiles.
      MapStyleId.dark: 'assets/map_styles/navia_night.json',
    },
    buildingsSourceId: 'openmaptiles',
    buildingsSourceLayer: 'building',
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
