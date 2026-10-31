# Navia architecture

This document describes how Navia is organized, the decisions behind it and
how future features, such as turn-by-turn navigation and offline routing,
will fit in.

## Principles

- **No Navia backend.** The app talks directly to replaceable,
  OpenStreetMap-based services.
- **The renderer is not the product.** MapLibre only draws. Search, routing
  and location never import MapLibre types.
- **Explicit user intent.** Location, search and routing requests happen only
  after a user action.
- **Small, testable units.** Widgets render state. Logic lives in Riverpod
  notifiers and repositories behind interfaces.

## Layers and folders

```
lib/
  main.dart               calls bootstrap()
  app/
    bootstrap.dart        loads SharedPreferences and PackageInfo, registers
                          data licenses, starts the ProviderScope
    app.dart              MaterialApp, Italian locale, theme mode
    config/app_config.dart  compile-time configuration and endpoints
    router/               named routes (map, settings)
    theme/                tokens, NaviaSurfaces extension, ThemeData
  core/
    errors/               ServiceFailure, ServiceException, Italian messages
    network/              JsonHttpClient (User-Agent, timeouts, error mapping)
    platform/             SystemShare (share sheet channel)
    l10n/                 all Italian copy and the in-app privacy policy
    utils/                formatters, external links
    widgets/              FloatingSurface, MapControlButton, NaviaIcon,
                          NaviaBackButton, NaviaIconBadge, logo
  features/<feature>/
    domain/               models and repository interfaces (pure Dart)
    data/                 implementations for concrete providers
    presentation/         notifiers, screens and widgets
  shared/
    models/               GeoPoint and GeoBounds (renderer-independent
                          WGS84), OSM category labels
    providers/            SharedPreferences and PackageInfo, overridden at
                          bootstrap
```

Dependencies point inward: `presentation → domain ← data`. Features may use
`core`, `shared` and `app/theme` or `app/config`. A feature may read another
feature's state through its providers (for example, navigation reads the
current location), but it never depends on another feature's widgets or
on the map renderer.

## State management

Riverpod 3 provides both dependency injection and state:

| Provider | Kind | Responsibility |
| --- | --- | --- |
| `themePreferenceProvider` | Notifier | Theme choice, persisted locally |
| `locationControllerProvider` | Notifier | Permission flow, current fix, foreground updates |
| `searchControllerProvider` | auto-dispose Notifier | Debounced queries, cache, stale-response guard |
| `navigationControllerProvider` | Notifier | Selection (with address lookup), origin, destination, mode, route state |
| `mapPreferencesProvider` | Notifier | Map appearance and 3D view, persisted |
| `favoritesProvider` | Notifier | Saved places, persisted |
| `mapLoadControllerProvider` | Notifier | Style loading, timeout, retry |
| `mapMarkersProvider` and `routeGeometryProvider` | derived | What the map must draw |
| `*RepositoryProvider` | Provider | Concrete service adapters, overridable in tests |

State classes are immutable. Asynchronous operations use a generation
counter, so a response that arrives after the input changed is discarded
instead of overwriting newer state.

## Map

`NaviaMapController` (in `features/map/domain`) is the only map API that
features use:

```dart
moveTo(GeoPoint, {zoom})
fitBounds(List<GeoPoint>, {padding})
showUserLocation(GeoPoint, {accuracy, heading})
showRoute(List<GeoPoint>)
showMarkers(List<MapMarker>)
```

`MapLibreNaviaMapController` implements it:

- The route and markers are GeoJSON sources with line and circle layers, drawn
  by the GPU. No widget is created per marker. Updates replace the source data
  and are skipped when nothing changed.
- The overlays are kept in memory and re-installed after every style load, so
  switching between the light and dark styles keeps the route.
- The user location puck uses MapLibre's `ManualLocationSource`. MapLibre never
  reads the device location: positions come only from the location feature.

`NaviaMapView` is the only widget that imports MapLibre. Tile providers are
just configuration: a `MapStyleSource` lists a style URL for each
`MapStyleId` (standard, vivid, minimal, dark), the attributions it requires,
and, optionally, the vector source layer that holds building heights.

### Map styles

| Appearance | OpenFreeMap style | Notes |
| --- | --- | --- |
| Automatico | Liberty or Navia Notte | Follows the app theme |
| Standard | Liberty | Points of interest, plus a built-in `building-3d` extrusion layer |
| Vivace | Bright | Points of interest |
| Essenziale | Navia Essenziale (asset) | Liberty with a muted palette |
| Scuro | Navia Notte (asset) | Liberty recolored for night use |

Navia Notte and Navia Essenziale are generated by
`tool/map_styles/build_night_style.py` and `build_essential_style.py`: they
download Liberty and recolor every paint color by layer type (land, water,
greens, roads and casings, buildings, labels), keeping Liberty's layers,
sources, sprites and fonts, so they still use OpenFreeMap tiles. The results
are committed under `assets/map_styles/` and loaded by `maplibre_gl` as
assets; a test checks that their remote resources are HTTPS. Rerun the
generators when Liberty changes.

The appearance is a `MapPreferences` setting, persisted together with the 3D
view. It is resolved explicitly into a style URL: the Flutter `ThemeMode` only
matters for Automatico.

When the style changes, `NaviaMapView` asks the adapter to capture the camera
(`queryCameraPosition`) before MapLibre receives the new style. After the
load, it re-installs Navia's sources and layers and restores the target,
zoom, bearing and pitch if the style moved them. The platform view is never
recreated for this.

Overlay colors (route, markers, buildings) follow the darkness of the map
style, not the app theme. The same applies to the system bar icons on the
map screen.

### 3D buildings

OpenFreeMap tiles follow the OpenMapTiles schema, whose `building` layer
carries `render_height` and `render_min_height` from OpenStreetMap. In 3D
mode the camera tilts to 60° and:

- With Liberty, the style's own `building-3d` layer is used.
- With the other styles, Navia adds a `fill-extrusion` layer from the same
  data, starting at zoom 14 and placed below the route layers, so routes stay
  visible.

Nothing is extruded without height data, and providers without a buildings
source simply do not offer 3D.

### Places on the map

A tap queries the rendered features of the style's `poi*` layers within a
small radius (`queryRenderedFeaturesInRect`). `MapFeatureParser` keeps the
first named point and maps its OpenMapTiles `class` or `subclass` to an
Italian label (`PlaceCategory`). Unknown classes get no label. Arbitrary
coordinates carry no business metadata, and Navia does not invent any.

A long-press selects the exact point and calls
`GeocodingRepository.reverse`. The address only labels the point: the picked
coordinates stay as they are. A failed lookup leaves the coordinates usable,
and a late answer for a replaced selection is discarded.

### Rebuild strategy

`MapScreen.build` watches no provider. Instead:

- `_MapLayer` watches only the style URL, the 3D setting and the retry
  attempt. The platform view is recreated only on an explicit retry after a
  load failure.
- The MapLibre location component is always enabled with a manual location
  source. It draws nothing until Navia pushes the first position, and it
  never reads the device location itself. Toggling it at runtime raced with
  the first position update and with camera animations, so it stays on.
- The search bar, controls, status overlays and `NavigationSheet` each watch
  their own slice of state with `select`.
- `_BackHandler` and `_MapSystemBars` wrap the scaffold but pass the same
  child instance, so their rebuilds stop at themselves.
- The navigation panel is docked to the bottom edge, capped at 60% of the
  available height, and scrolls internally, so the map stays visible on
  small and landscape screens. Route framing leaves room for it and for the
  control column on the right.
- MapLibre's own attribution button sits under the panel; the always-visible
  attribution chip at the top shows the same notices and links.
- Side effects that the map needs, such as the puck, markers, route and
  camera framing, run in `ref.listen` callbacks, not during build.

Expanding the sheet, typing in search or receiving a route therefore never
rebuilds the map widget.

### Coordinates

`GeoPoint` has named `latitude` and `longitude` fields. GeoJSON, OSRM and
Photon use `[longitude, latitude]` order: always convert with
`GeoPoint.toLngLat()` or `GeoPoint.tryParseLngLat()`, which also validate
ranges. MapLibre's `LatLng` puts latitude first.

## Location

`LocationRepository` wraps `geolocator`. It uses the Android `LocationManager`
(`forceLocationManager: true`), so it works without Google Play Services.
`LocationController`:

1. Does nothing until the user taps the location button, or calculates a
   route from "La tua posizione".
2. Checks that location services are on, then the permission. It prompts only
   if the permission is not already granted or permanently denied.
3. Takes one fresh fix with a timeout, then streams updates with a 5 m
   distance filter.
4. Pauses the stream when the app is hidden and resumes it when the app
   returns.

Failures (services off, denied, permanently denied, unavailable) become
actionable Italian messages that link to the right system settings screen.

## Network and errors

`JsonHttpClient` adds the identifying `User-Agent`, applies a timeout and maps
failures to `ServiceFailure`:

| Situation | Failure |
| --- | --- |
| Socket or DNS error | `noConnection` |
| No answer in time | `timeout` |
| HTTP 5xx | `unavailable` |
| HTTP 429 | `rateLimited` |
| Body that is not JSON | `malformedResponse` |
| Service answered with nothing | `noResult` |
| Invalid input | `invalidRequest` |
| Endpoint not configured | `notConfigured` |

Raw exceptions are logged with `debugPrint` for developers and never shown
to users.

## Search

`GeocodingRepository.search(query, near:)` returns `Place`s.
`PhotonGeocodingRepository` is the current implementation:

- It skips malformed features, such as missing names or invalid coordinates,
  instead of failing the whole response.
- It sends the bias position rounded to two decimals (about 1 km).

`SearchController` debounces typing (450 ms), ignores queries shorter than
3 characters, keeps a 30-entry FIFO cache and drops outdated responses.

### Provider evaluation

| Provider | Autocomplete allowed | Notes |
| --- | --- | --- |
| Nominatim (public) | No | The policy forbids autocomplete. Not used. |
| Photon (public komoot) | Fair use | Built for search-as-you-type. This is the default. |
| Photon (self-hosted) | Yes | Recommended for a large public release. |
| Pelias or commercial | Depends | Needs an API key, which must not be embedded in the APK. |

### Category markers

Each `PoiCategory` has a marker color and image
(`place_marker_style.dart`): a colored disc with a white ring and the white
category icon, rendered once per session from the SVG icon set into PNGs.
`NaviaMapController.setPlaceImages` registers them, and they are added again
to every new style once its layers are installed (also when the images
arrive during the installation). Places are a symbol layer: the icon always
shows (`icon-allow-overlap`), the name from zoom 14.5 and only where it does
not collide. A fill-extrusion layer draws an 8 m square column in the
category color under each place from zoom 15, visible when the map is
tilted.

## Routing

`RoutingRepository` exposes the `supportedModes` and
`route(origin, destination, mode)` methods. The UI offers only the modes the
configured provider supports, and hides routing entirely when it supports
none.

`OsrmRoutingRepository`:

- Has one base URL per mode, because OSRM servers serve one profile each.
- Requests `overview=full&geometries=geojson`.
- Maps OSRM codes (`NoRoute`, `NoSegment`, `InvalidQuery` and so on) to
  failures.
- Validates every coordinate it receives.
- Spaces requests by at least one second, as the FOSSGIS policy requires.

`NavigationController` manages the planning flow:

```
selection --(Indicazioni / Parti da qui)--> origin / destination
both ends known --> loading --> ready | failed   (no separate step)
swap or mode change --> recalculated
clear --> nothing planned
```

`setOrigin` and `setDestination` only edit the plan; the user-facing
actions calculate the route as soon as both ends are known. "Calcola
percorso" is shown only to retry a plan that was edited without a route.

When the origin is "La tua posizione", it is resolved through
`LocationController` only when the route is calculated.

### Turn-by-turn guidance

- **Maneuvers:** routes are requested with `steps=true`; `RouteStep` keeps
  each maneuver's kind, direction, street, roundabout exit and location.
  `RouteInstructions` phrases them in Italian and rounds distances for
  speech.
- **Tracker:** `GuidanceTracker` is pure Dart. For each position it advances
  past maneuvers within a "reached" radius, announces the next maneuver
  ahead and again when near (driving 400/60 m, cycling 200/35 m, walking
  100/20 m), detects arrival, and reports off route after two updates more
  than 60/45/35 m from the route polyline (flat projection, city scale).
- **Controller:** `GuidanceController` listens to the location stream and
  the route, speaks through `VoiceGuide` (Android text-to-speech via
  `flutter_tts`, offline with installed voices), keeps the screen on through
  the `navia/screen` channel, and recalculates from the current position at
  most every 15 seconds. A failed recalculation stops guidance and the panel
  shows the error.
- **Foreground only:** location updates pause when the app is hidden, and
  Navia declares no background location or foreground service.
- **UI:** `GuidanceBanner` replaces the search bar and category filters,
  `GuidancePanel` replaces the planning panel, and the map follows the user
  at zoom 17 with the GPS heading; recalculated routes do not reframe the
  camera during guidance.

### Wikipedia

`WikipediaRepository` reads the REST summary of the article linked by the
`wikipedia` tag when it is Italian; otherwise it asks Wikidata for the
`itwiki` (then `enwiki`) sitelink. Disambiguation pages and missing articles
give no section. `placeArticleProvider` is an auto-disposed family keyed by
the place, so the request happens only while its card is shown.

### Engine evaluation

| Engine | Strengths | Concerns |
| --- | --- | --- |
| **OSRM** | Very fast, simple API, public FOSSGIS servers for car, bike and foot | One profile per instance, limited costing options, no time-dependent routing |
| **Valhalla** | Many profiles in one instance, rich turn-by-turn maneuvers, on-device builds exist | Heavier to host; public instances have stricter limits |
| **GraphHopper** | Good profiles, Java and Android heritage, an offline-capable core | The hosted API needs a key; self-hosting the open core is required |

OSRM was chosen for the first iteration because public endpoints with a
clear policy exist for all three travel modes. Valhalla is the likely next
step for turn-by-turn guidance, because its maneuver data maps directly to
Italian voice and text instructions.

## Future integration strategy

1. **Turn-by-turn guidance.** Extend `NavRoute` with legs, steps and
   maneuvers (OSRM `steps=true` or Valhalla maneuvers), add a guidance state
   machine fed by `LocationController` updates, and add
   map-matching, off-route detection and rerouting. This needs foreground
   service handling on Android and a clear in-app explanation before any
   continuous location use.
2. **Offline routing.** Add an on-device `RoutingRepository` (for example
   Valhalla or GraphHopper with downloaded graph tiles). A composite
   repository can prefer the offline engine and fall back to online, with no
   change to the UI.
3. **Offline maps.** Add a `MapStyleSource` that points to local MBTiles or
   PMTiles, plus a region download manager.
4. **History.** Recent destinations, stored locally like favorites. No cloud
   sync without explicit opt-in.

## Places

`features/places` lists real OpenStreetMap points of interest.

- **Domain:** `Poi` (an `OsmRef` such as `node/123`, a point and optional
  name, category, address, raw `opening_hours`, validated website and phone,
  cuisine and wheelchair access), `PoiCategory` (13 discovery categories,
  each mapped to OSM tags), `PlacesRepository`, `PlaceLinks` (URL and phone
  validation, share text, map links) and `OpeningHours`.
- **Data:** `OverpassPlacesRepository` sends one query per category and area:
  `nwr[key~"^(values)$"]` statements inside a global `[bbox]`, `out tags
  center 150`, a 15-second server timeout (25 seconds on the client) and 2
  seconds between requests. Ways and relations use their center. Invalid
  elements are skipped; a server error remark without results is a failure.
  `PlacesCache` keeps up to 24 areas in memory for 15 minutes (LRU).
- **Discovery:** `PlaceDiscoveryController` acts only while a category is
  selected. The map reports its visible bounds and zoom when the camera is
  idle; after 700 ms the controller:
  1. asks to zoom in below zoom 13 or above a 0.12 degree span;
  2. does nothing if the shown area already covers the view;
  3. serves a cached area that covers the view;
  4. otherwise requests the view plus 25 %, snapped outwards to a 0.01 degree
     grid, unless the same request is already in flight.
  A generation counter discards answers for an older view or category.
- **Rendering:** places are a GeoJSON source with a circle layer and a
  symbol layer (`Noto Sans Regular`, which every OpenFreeMap style serves)
  added below the route. MapLibre hides colliding labels; names appear from
  zoom 14.5 and the selected place sorts first. While a filter is active the
  style's own `poi*` layers are hidden to avoid duplicate labels; the
  setting is re-applied after style changes. Taps query Navia's place layers
  before the style's POIs.
- **Selection:** `NavigationController.selectPlace` stores the `Poi` with the
  selection, so the place card can show its details and the map can
  highlight it. Opening hours get an open or closed badge only when
  `OpeningHours.tryParse` accepts the whole value and the place lies in the
  Central European Time area, whose rules Navia computes without a time zone
  database. Otherwise the raw value is shown.
- **Actions:** sharing goes through a `MethodChannel` (`navia/share`) in
  `MainActivity` that opens the system share sheet; copying uses the
  clipboard; phone numbers open the dialer through a `tel:` link (no
  `CALL_PHONE` permission); websites and OSM objects open in the browser.
  Every action needs a tap.

### Offline places

- **Datasets:** built monthly in CI from Geofabrik extracts and published as
  assets of the `places-data` release: `places-<region>.jsonl.gz` (one
  `{"id", "lat", "lon", "tags"}` object per line) and `manifest.json` with
  size, SHA-256, count and bounding box. `tool/places/poi_tags.json` lists
  the selected tags; a test keeps it equal to `PoiCategory`.
- **Download:** `PlaceDataClient` streams the file with progress, aborts on
  cancellation or a 30-second stall, and rejects a wrong size or checksum.
  Nothing is requested before the user opens the screen, and nothing is
  downloaded without confirmation.
- **Storage:** `OfflinePlacesStore` splits the data into 0.1 degree cell
  files under the app support directory (private, removed with the app,
  excluded from backup), writing in batches to bound memory, in a
  background isolate. A region is replaced atomically through a staging
  directory.
- **Queries:** `LocalFirstPlacesRepository` answers from installed regions
  whose bounding box contains the view's center, reading only the cells of
  the view in an isolate and returning the 150 places nearest the center;
  elsewhere it falls back to Overpass. Discovery clears its cache and
  reloads when a region is installed or deleted.

See [DATA_LICENSES.md](DATA_LICENSES.md) for Overpass usage, the license of
the published datasets and how to replace the provider.

## Favorites

`FavoritesRepository` stores a versioned JSON list (`favorites.v1`) in
`SharedPreferences`. A handful of places does not justify SQLite, and the
versioned key allows a later migration. Optional fields (`osm`, `category`,
`address`) were added without changing the key: older entries simply lack
them. Corrupted entries are skipped instead of crashing.
`FavoritesController`:

- trims names and caps them at 60 characters;
- rejects a place already saved with the same OpenStreetMap reference, or
  within 15 m of an existing favorite (haversine distance on `GeoPoint`);
- assigns IDs that stay unique even with coarse clocks;
- supports undoing a delete.

## Testing

- **Unit tests:** parsers (Photon, OSRM), the HTTP failure mapping,
  formatters, coordinate validation, GeoJSON encoding, and every notifier
  (theme, location, search debounce and stale responses, navigation
  transitions).
- **Widget tests:** the settings and privacy screens, the navigation sheet,
  the place card with sharing and copying, the layers sheet and the
  favorites screen, with fake repositories and mocked platform channels.
- **Places:** Overpass query building and parsing, missing metadata,
  categories, bounds, link validation, opening hours and time zone rules,
  cache expiry and eviction, viewport thresholds, deduplication and stale
  answers.
- **Not covered by automated tests:** the MapLibre platform view, which needs
  a device. Verify it manually on Android.

Test doubles live only in `test/`.
