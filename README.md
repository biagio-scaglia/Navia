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

> **Status: early development (v0.7).** Navia offers turn-by-turn guidance
> with Italian voice instructions while the app is open. See
> [Current limitations](#current-limitations).

## Features

- **Map:** fullscreen vector map of real OpenStreetMap data (streets,
  building footprints, street names, neighborhoods, parks, water and points
  of interest), centered on Bari at zoom 14 and explorable worldwide.
- **Map appearance:** choose Automatico (follows the app theme), Standard,
  Vivace, Essenziale or Scuro. Essenziale and Scuro ("Navia Notte") are
  Navia's own styles, generated from OpenFreeMap Liberty: a muted day style
  and a readable night style, both with points of interest and 3D
  buildings. The camera, your route and your markers are kept when you
  switch.
- **3D buildings:** an optional tilted view that extrudes buildings from the
  real height data in OpenStreetMap. Buildings without height data stay
  flat; nothing is invented.
- **Location:** shows your position on request. Permission is asked only when
  you tap the location button, and updates stop when the app is in background.
- **Search:** finds addresses and places with debounced search-as-you-type,
  ranked around your approximate position.
- **Place discovery:** filter real OpenStreetMap places by category
  (Ristoranti, Bar e caffè, Supermercati, Farmacie, Ospedali, Musei,
  Attrazioni, Parchi, Hotel, Trasporti, Parcheggi, Carburante, Bancomat).
  Places appear on the map with their names; tap one to open its card.
- **Offline places:** download the places of an Italian macro-region
  (*Impostazioni → Luoghi offline*), after a confirmation that shows the
  size, with a progress bar and the option to cancel. Downloaded regions
  answer instantly and without a connection; you can update or delete them
  at any time. Sud is 3 MB (126,088 places), all of Italy about 22 MB.
- **Category markers:** each category has its own colored marker with its
  icon, and small colored columns rise under the markers when the map is
  tilted.
- **Fuel prices:** download the daily prices of all Italian fuel stations
  (about 1.5 MB, *Impostazioni → Luoghi offline*) from the Ministry's open
  data (MIMIT, IODL 2.0); fuel station cards then show self service and
  served prices for each fuel, with the report date.
- **Wikipedia:** places linked to Wikipedia or Wikidata show the summary of
  the Italian article (English as fallback) with its image and a link.
- **Place cards:** name, category, address, opening hours (with an "Aperto
  ora" / "Chiuso ora" badge only when it can be computed reliably), cuisine,
  wheelchair access, phone and website, each shown only when OpenStreetMap
  has it. Actions: directions, start here, save, share through the Android
  share sheet, copy coordinates, call (opens the dialer), open the website,
  view the object on OpenStreetMap.
- **Map points:** tap a point of interest drawn by the map style to see its
  name and category, or long-press anywhere to pick a point and look up its
  address.
- **Favorites:** save places under a custom name, on the device only, with
  their OpenStreetMap category, address and identifier when available. Open
  them, plan a route to them, pick them as origin or destination (also
  offline, from the search screen), rename or delete them (with undo).
  Duplicates are prevented by OpenStreetMap identifier or within 15 m.
- **Routing:** builds A-to-B routes by car, bike or on foot as soon as both
  ends are known, with "your location" available as the origin. It shows
  distance, estimated duration, arrival time and the route geometry on the
  map, and lets you swap and clear points. Without location permission,
  choose the origin by search, on the map or from favorites.
- **Turn-by-turn guidance:** "Avvia" starts guidance from your position:
  the next maneuver with its arrow and distance, Italian voice instructions
  through Android's text-to-speech (works offline, can be muted), the camera
  following you, automatic recalculation when you leave the route, arrival
  time and remaining distance. The full instruction list is also shown in
  the route summary.
- **Errors:** handles offline mode, service failures, timeouts, denied
  permissions and disabled GPS with Italian messages that tell you what to do.
- **Privacy:** an in-app privacy policy with a plain-language summary
  (*Impostazioni → Informativa sulla privacy*), also in
  [PRIVACY.md](PRIVACY.md).
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
| Points of interest | [Overpass API](https://overpass-api.de) (OpenStreetMap data) |
| Sharing | Android share sheet through a small platform channel; no SDK |
| Location | `geolocator`, using the Android `LocationManager` |
| Storage | `shared_preferences` for preferences and favorites, on the device only |

## Online services and privacy

Navia has no server of its own. These third-party services receive requests:

| Service | When | What it receives |
| --- | --- | --- |
| OpenFreeMap | While the map is shown | Style, tile and font requests for the visible area |
| Photon (komoot) | While you type a search, or when you long-press the map | The search text, plus your position rounded to about 1 km for ranking; or the long-pressed point, to find its address |
| OSRM by FOSSGIS | When a route is calculated | Origin and destination coordinates |
| Overpass API | When a place category is selected and the map stops moving | The category and the visible area, enlarged and rounded to about 1 km |

Every request carries a `User-Agent` that identifies Navia and its version, as
the providers require. Navia does not store your location history, does not
request background location, and excludes its data from Android cloud
backup. The full description is in the [privacy policy](PRIVACY.md).

Android permissions: `INTERNET`, `ACCESS_COARSE_LOCATION` and
`ACCESS_FINE_LOCATION` (asked only when you use your position), and
`ACCESS_NETWORK_STATE`, which MapLibre needs to detect connectivity. The
`ACCESS_WIFI_STATE` permission requested by MapLibre is removed.

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
- **Overpass API** public instances are shared community infrastructure and
  are often at capacity. Navia queries only while a category is selected,
  700 ms after the map stops, above zoom 13 and for areas up to about 13 km;
  it reuses the loaded area for small pans, caches answers for 15 minutes,
  spaces requests by 2 seconds, skips duplicate requests and returns at most
  150 places per area.

A widely distributed build should point to self-hosted or commercially
agreed instances (see [Configuration](#configuration)). Navia deliberately
does **not** use the public Nominatim service, whose policy forbids
autocomplete.

## Requirements

- Flutter 3.41 (stable channel) and Dart 3.11
- JDK 21 (the `maplibre_gl` plugin compiles with Java 21; Android Studio bundles it)
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
| `NAVIA_OVERPASS_URL` | `https://overpass-api.de/api/interpreter` | Places come only from downloaded regions |
| `NAVIA_FUEL_DATA_URL` | `https://github.com/biagio-scaglia/Navia/releases/download/fuel-data/fuel-prices.json.gz` | Fuel prices are hidden |
| `NAVIA_PLACES_DATA_URL` | `https://github.com/biagio-scaglia/Navia/releases/download/places-data` | Offline places are hidden |

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
    places/      OpenStreetMap places, Overpass and offline sources, discovery,
                 place card
    favorites/   saved places, stored locally
    settings/    preferences and settings screen
  shared/     geographic model and app-wide providers
assets/       logo and icon set
tool/brand/   generator for the logo and launcher icons
tool/places/  generator of the offline place datasets (run monthly in CI)
docs/         architecture, roadmap, data licenses and brand guide
PRIVACY.md    privacy policy (draft for legal review)
```

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design and
[docs/ROADMAP.md](docs/ROADMAP.md) for what comes next.

## Current limitations

- Guidance runs only while the app is open and in the foreground: Navia
  keeps the screen on but never uses background location. Voice
  instructions need an Italian text-to-speech voice installed on the
  device.
- Instructions come from OSRM maneuvers; lane guidance, speed limits and
  traffic are not available.
- Travel times are estimates without live traffic.
- Search, routing and the map need an internet connection. Only places can
  be downloaded for offline use; offline maps and routing are planned.
- The default services are public community instances with fair-use limits.
  They are suitable for development and small-scale use, not for a large
  public release.
- Open or closed badges use Italian national holidays; local patron saint
  days and school holidays are not computed (Wikidata patron data is too
  ambiguous, and school calendars are not published as data).
- Fuel prices are the ones operators report to the Ministry and may differ
  at the pump; they are matched to OpenStreetMap stations within 80 m, so a
  station missing from OpenStreetMap shows no prices.
- Speed limits and lane guidance are not shown: the public OSRM server does
  not provide them. Bari's AMTAB timetable feed is expired (valid until the
  end of 2023), so public transport waits for current data.
- Outside downloaded regions, place discovery depends on public Overpass
  instances, which are often overloaded: answers can take about 40 seconds
  or be refused, and Navia then offers to retry or to download the area.
- Offline places cover Italy only, by macro-region, and are refreshed
  monthly. A region "covers" the view when its bounding box contains the
  view's center, so near borders a neighboring region may also be needed.
- The open or closed status is computed only for the common `opening_hours`
  syntax and only in the Central European Time area around Italy; other
  cases show the original hours without a status.
- Details of places drawn by the map style itself (not by the category
  filters) are limited to name and category.
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
hosted by [FOSSGIS](https://routing.openstreetmap.de). Places from the
[Overpass API](https://overpass-api.de). The app shows these credits on the
map, in the route summary, in the search screen, in each place card and in
the settings. See [docs/DATA_LICENSES.md](docs/DATA_LICENSES.md) for the
obligations that come with the data.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Navia's source code, logo and icon set are released under the
[MIT License](LICENSE). The MIT License does not apply to the map data:
OpenStreetMap data stays under the ODbL, and third-party libraries keep
their own licenses, which you can browse in the app under
*Impostazioni → Licenze open source*.
