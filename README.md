<p align="center">
  <img src="assets/brand/navia_logo_512.png" alt="Navia logo" width="112">
</p>

<h1 align="center">Navia</h1>

<p align="center">
  An open-source, privacy-friendly navigation app for Android, built with
  Flutter, MapLibre and OpenStreetMap.
</p>

Navia aims to become a lightweight alternative to proprietary map apps. It
starts with Bari, Italy, and will expand from there. It has no account, no
ads, no analytics and no Navia backend: the app talks directly to open,
OpenStreetMap-based services, and only when you use the feature that needs
them.

> **Status: early development (v0.3).** Navia shows routes but does not yet
> provide turn-by-turn guidance. See [Current limitations](#current-limitations).

## Features

- **Map:** fullscreen vector map of real OpenStreetMap data (streets,
  building footprints, street names, neighborhoods, parks, water and points
  of interest), centered on Bari at zoom 14 and explorable worldwide.
- **Map appearance:** choose Automatico (follows the app theme), Standard,
  Vivace, Essenziale or Scuro. The camera position, zoom, bearing and pitch,
  your route and your markers are all kept when you switch.
- **3D buildings:** an optional tilted view that extrudes buildings from the
  real height data in OpenStreetMap. Buildings without height data stay
  flat; nothing is invented.
- **Location:** shows your position on request. Permission is asked only when
  you tap the location button, and updates stop when the app is in background.
- **Search:** finds addresses and places with debounced search-as-you-type,
  ranked around your approximate position.
- **Places:** tap a point of interest drawn on the map to see its name and
  category. Long-press anywhere to pick a point; Navia looks up its address
  and shows the coordinates. Use any place as origin or destination, or save
  it.
- **Favorites:** save places under a custom name, on the device only. You can
  open, rename or delete them (with undo), and duplicates within 15 m are
  prevented.
- **Routing:** builds A-to-B routes by car, bike or on foot, with "your
  location" available as the origin. It shows distance, estimated duration and
  the actual route geometry on the map, and lets you swap and clear points.
- **Errors:** handles offline mode, service failures, timeouts, denied
  permissions and disabled GPS with Italian messages that tell you what to do.
- **Settings:** light, dark or system theme (remembered on the device),
  location permission status, a list of which services receive which data,
  map attributions, open-source licenses and the app version.

The user interface is in Italian. Code and documentation are in English.

## Technology

| Area | Choice |
| --- | --- |
| UI | Flutter, Material 3 with a custom design system |
| State and dependency injection | Riverpod 3 |
| Map renderer | MapLibre Native, through `maplibre_gl` |
| Map tiles and styles | [OpenFreeMap](https://openfreemap.org) styles Liberty, Bright, Positron and Dark (OpenMapTiles schema, OpenStreetMap data) |
| Geocoding | [Photon](https://photon.komoot.io) (OpenStreetMap data) |
| Routing | [OSRM](https://project-osrm.org) on the [FOSSGIS servers](https://routing.openstreetmap.de) |
| Location | `geolocator`, using the Android `LocationManager` |
| Storage | `shared_preferences` for preferences and favorites, on the device only |

## Online services and privacy

Navia has no server of its own. These third-party services receive requests:

| Service | When | What it receives |
| --- | --- | --- |
| OpenFreeMap | While the map is shown | Style, tile and font requests for the visible area |
| Photon (komoot) | While you type a search, or when you long-press the map | The search text, plus your position rounded to about 1 km for ranking; or the long-pressed point, to find its address |
| OSRM by FOSSGIS | When you calculate a route | Origin and destination coordinates |

Every request carries a `User-Agent` that identifies Navia and its version, as
the providers require. Navia does not store your location history and does
not request background location.

### Provider usage policies

The default endpoints are public community services, meant for **fair,
low-volume use**:

- **FOSSGIS routing** allows at most one request per second, requires a valid
  User-Agent and OpenStreetMap attribution with a "fix the map" link, and
  forbids heavy usage. Navia enforces the one-request-per-second limit on the
  client and only sends a route request when you ask for one.
- **Photon** asks for fair use and throttles heavy use. Navia waits for a
  pause in typing (450 ms), needs at least 3 characters, caches results and
  discards outdated responses.

A widely distributed build should point to self-hosted or commercially
agreed instances (see [Configuration](#configuration)). Navia deliberately
does **not** use the public Nominatim service, whose policy forbids
autocomplete.

## Requirements

- Flutter 3.41 (stable channel) and Dart 3.11
- JDK 17
- Android SDK with platform 36 and build tools; accept the licenses with
  `flutter doctor --android-licenses`
- An Android device or emulator running Android 7.0 (API 24) or later

## Getting started

```sh
git clone https://github.com/biagio-scaglia/Navia.git
cd Navia
flutter pub get
flutter run
```

Run the same checks as CI before you open a pull request:

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Configuration

Service endpoints are set at build time with `--dart-define`, so no secret is
ever embedded in the APK:

| Variable | Default | Effect when empty |
| --- | --- | --- |
| `NAVIA_PHOTON_URL` | `https://photon.komoot.io` | Search is hidden |
| `NAVIA_OSRM_CAR_URL` | `https://routing.openstreetmap.de/routed-car` | Car mode is hidden |
| `NAVIA_OSRM_BIKE_URL` | `https://routing.openstreetmap.de/routed-bike` | Bike mode is hidden |
| `NAVIA_OSRM_FOOT_URL` | `https://routing.openstreetmap.de/routed-foot` | Walking mode is hidden |

For example, to use a self-hosted Photon instance:

```sh
flutter run --dart-define=NAVIA_PHOTON_URL=https://photon.example.org
```

The map styles are defined in `lib/app/config/app_config.dart`. OpenFreeMap's
public instance is free, also for commercial use, with no request limits and
no API key; it requires attribution, which Navia always shows.

## Building for Android

```sh
flutter build apk --debug
flutter build apk --release
```

Release builds are signed with the key described in `android/key.properties`
(never committed):

```properties
storeFile=/absolute/path/to/navia.jks
storePassword=...
keyAlias=navia
keyPassword=...
```

Without that file, release builds fall back to the debug key so that CI and
local builds keep working. **Do not publish APKs signed with the debug key.**

The launcher icon and logo are generated by
`python tool/brand/generate_brand_assets.py` (requires Pillow). See
[docs/BRAND.md](docs/BRAND.md).

## Project structure

```
lib/
  app/        bootstrap, root widget, routes, theme, configuration
  core/       errors, HTTP client, copy, formatters, shared widgets and icons
  features/
    location/    device location and permissions
    map/         MapLibre renderer behind a NaviaMapController interface
    navigation/  routing domain, OSRM provider, planning state, sheet UI
    search/      geocoding domain, Photon provider, search UI
    favorites/   saved places, stored locally
    settings/    preferences and settings screen
  shared/     geographic model and app-wide providers
assets/       logo and icon set
tool/brand/   generator for the logo and launcher icons
docs/         architecture, roadmap and brand guide
```

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design and
[docs/ROADMAP.md](docs/ROADMAP.md) for what comes next.

## Current limitations

- There is no turn-by-turn guidance, voice instructions or automatic
  rerouting. Routes are shown as an overview.
- Travel times are estimates without live traffic.
- Search, routing and the map need an internet connection. There are no
  offline maps or offline routing yet.
- The default services are public community instances with fair-use limits.
  They are suitable for development and small-scale use, not for a large
  public release.
- The Essenziale and Scuro styles do not draw points of interest, so tapping
  places only works with Standard and Vivace.
- 3D heights come from OpenStreetMap, where many buildings have no height
  data and stay flat.
- Navia has been designed and tested for Bari. The map and services work
  worldwide, but other areas have had little testing.
- The `maplibre_gl` plugin depends on Google Play Services libraries for its
  own location engine. Navia does not use that engine (it feeds positions
  from `geolocator`), but the dependency is still in the APK, which matters
  for F-Droid distribution.

## Attribution

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright),
available under the Open Database License (ODbL). Vector tiles ©
[OpenMapTiles](https://www.openmaptiles.org/), served by
[OpenFreeMap](https://openfreemap.org/). Search by
[Photon](https://photon.komoot.io). Routing by [OSRM](https://project-osrm.org),
hosted by [FOSSGIS](https://routing.openstreetmap.de). The app shows these
credits on the map, in the route summary, in the search screen and in the
settings.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Navia's source code, logo and icon set are released under the
[MIT License](LICENSE). Third-party libraries and data keep their own
licenses, which you can browse in the app under
*Impostazioni → Licenze open source*.
