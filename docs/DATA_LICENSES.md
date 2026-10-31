# Data licenses and attribution

This document lists the licenses and usage conditions that apply to the data
and services Navia uses. It is a technical summary for maintainers, not legal
advice; have it reviewed before a public release.

## Two different licenses

- **Navia's code, logo and icon set:** MIT License ([LICENSE](../LICENSE)).
- **Geographic data:** OpenStreetMap data is licensed under the
  [Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/).

Publishing Navia under MIT does **not** relicense OpenStreetMap data. Any
data Navia displays, or that a user exports from it (for example by sharing
a place), remains ODbL data.

## OpenStreetMap (ODbL)

Obligations relevant to Navia:

- **Attribution.** Show "© OpenStreetMap contributors" with a link to
  <https://www.openstreetmap.org/copyright>, where users see the map. Navia
  shows it in the always-visible map chip (with the full list behind it),
  in the route summary, in the search screen, in every place card ("Dati ©
  OpenStreetMap", linking to the object) and in the settings. See the
  [attribution guidelines](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines).
- **Share-alike** applies to *derivative databases* that are publicly used.
  The offline place datasets published in the `places-data` release are
  such a derivative database: they are offered under the ODbL 1.0, with the
  attribution and license notice in the release description, in the app's
  license list and on the *Luoghi offline* screen. The generator
  (`tool/places/`) is public, so anyone can rebuild them from the source
  extracts. Favorites hold a few fields of single places for the user's own
  device.
- **Produced works**, such as screenshots of the map, need attribution but
  are not themselves under the ODbL.

## Services

| Service | Data | Conditions | Navia's measures |
| --- | --- | --- | --- |
| [OpenFreeMap](https://openfreemap.org) | Vector tiles (OpenMapTiles schema, © OpenMapTiles, © OpenStreetMap contributors) | Free, also for commercial use, no API key, no request limits; attribution required | Attribution chip and list |
| [Photon by komoot](https://photon.komoot.io) | Geocoding from OpenStreetMap data | Fair use; heavy users must self-host | Debounce, minimum length, cache, stale response protection |
| [OSRM on FOSSGIS](https://routing.openstreetmap.de) | Routes from OpenStreetMap data | At most 1 request per second, valid User-Agent, attribution with a fix-the-map link, no heavy use | Client-side rate limit, requests only on user action, attribution and link in the route summary |
| [Overpass API](https://overpass-api.de) | Raw OpenStreetMap objects and tags | Public instances are shared infrastructure; the main instance asks to stay under about 10,000 queries and 1 GB per day per user and answers 429 or 502/504 when busy | Queries only after a category is chosen and the map is idle, zoom 13 or more, bounded areas, 150 results at most, 2-second spacing, deduplication, 15-minute cache, user-triggered retry |

The public Overpass instances are frequently at capacity. They are suitable
for development and small-scale use, not as the backend of a widely used
app.

### Replacing the places provider

Place discovery goes through the `PlacesRepository` interface
(`lib/features/places/domain/places_repository.dart`). Options as usage
grows:

1. **Own Overpass instance**, set with
   `--dart-define=NAVIA_OVERPASS_URL=https://example.org/api/interpreter`.
   No code change.
2. **Regional extracts (implemented for Italy):** the `Places data`
   workflow downloads the Geofabrik extracts of the five Italian
   macro-regions every month, keeps only the objects of Navia's categories
   with the displayed tags (`tool/places/build_places.py`) and publishes
   gzipped JSON lines plus `manifest.json` as release assets, at no cost.
   Users download a region on request; the app checks its SHA-256 and
   queries it on the device. Adding a country means adding its extracts to
   the workflow and `build_manifest.py`. Geofabrik asks for reasonable use
   of its download server; one download per region per month is well
   within it.
3. **Another API** returning OpenStreetMap objects, implemented as a new
   `PlacesRepository`.

## Third-party packages

Flutter packages keep their own licenses (mostly BSD-3-Clause, MIT and
Apache-2.0). The app lists all of them, generated from the build, under
*Impostazioni → Licenze open source*, together with notices for the map data.
Notable native dependencies: MapLibre Native (BSD-2-Clause) and the Google
Play Services location libraries pulled in by `maplibre_gl`.

## Fuel prices (MIMIT)

The daily station registry and prices of the Ministero delle Imprese e del
Made in Italy ("Osservaprezzi carburanti") are published under the Italian
Open Data License 2.0, which requires attribution. The Ministry's server
does not answer GitHub's machines (requests time out from outside Italy), so
the app downloads the two files directly when the user asks, joins them on
the device, and keeps them separate from the ODbL place datasets; the place
card credits the source and license.

## Italian open data checked but not used

- **Ministry of Culture (dati.cultura.gov.it):** the domain did not resolve
  in October 2026.
- **AMTAB GTFS (opendata.comune.bari.it, CC BY 4.0):** the feed is valid only
  until 31 December 2023.
- **Patron saints (Wikidata):** many saints have several feast days, so a
  local holiday cannot be computed reliably.

## Open-Meteo and Valhalla

Open-Meteo forecasts are free for non-commercial use without a key and
require attribution (CC BY 4.0); the weather line names Open-Meteo. A
commercial distribution of Navia needs Open-Meteo's commercial plan or a
self-hosted instance (`NAVIA_WEATHER_URL`). The FOSSGIS Valhalla server
follows the same fair-use terms as the routing servers; reachable areas
show "Valhalla (FOSSGIS) · © OpenStreetMap".

## Wikipedia and Wikimedia Commons

Article summaries are licensed under CC BY-SA 4.0; the place card names the
source and license and links to the article. Thumbnails come from Wikimedia
Commons with licenses that vary per image; they are shown linked to the
article, whose page credits them. Navia does not store or redistribute
either.

## Privacy implications

Each external request reveals the user's IP address and the request
contents to the provider. What each service receives is listed in
[PRIVACY.md](../PRIVACY.md).
