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
    l10n/app_strings.dart all Italian copy
    utils/                formatters, external links
    widgets/              FloatingSurface, MapControlButton, NaviaIcon, logo
  features/<feature>/
    domain/               models and repository interfaces (pure Dart)
    data/                 implementations for concrete providers
    presentation/         notifiers, screens and widgets
  shared/
    models/geo_point.dart renderer-independent WGS84 coordinate
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
| `navigationControllerProvider` | Notifier | Selection, origin, destination, mode, route state |
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
just configuration: a `MapStyleSource` has light and dark style URLs plus the
attributions it requires.

### Rebuild strategy

`MapScreen.build` watches no provider. Instead:

- `_MapLayer` watches only the style URL, the retry attempt and whether a
  position exists. The platform view is recreated only on an explicit retry
  after a load failure.
- The search bar, controls, status overlays and `NavigationSheet` each watch
  their own slice of state with `select`.
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
selection --(Partenza/Destinazione)--> origin / destination
origin + destination --(Calcola percorso)--> loading --> ready | failed
changing a waypoint --> route discarded (idle)
changing mode with a route shown --> recalculated
clear --> nothing planned
```

When the origin is "La tua posizione", it is resolved through
`LocationController` only when the route is calculated.

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
4. **Favorites and history.** Store them locally only, behind a repository
   that has an export option. No cloud sync without explicit opt-in.

## Testing

- **Unit tests:** parsers (Photon, OSRM), the HTTP failure mapping,
  formatters, coordinate validation, GeoJSON encoding, and every notifier
  (theme, location, search debounce and stale responses, navigation
  transitions).
- **Widget tests:** the settings screen and the navigation sheet, with fake
  repositories.
- **Not covered by automated tests:** the MapLibre platform view, which needs
  a device. Verify it manually on Android.

Test doubles live only in `test/`.
