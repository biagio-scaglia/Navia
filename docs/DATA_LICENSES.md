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
  Navia does not build or publish a database: it displays query results and
  keeps a short-lived in-memory cache (15 minutes). Favorites hold a few
  fields of single places for the user's own device. If Navia ever
  publishes a derived dataset (for example a downloadable regional POI
  extract), that dataset must be offered under the ODbL.
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
2. **Regional extracts:** a periodically generated, downloadable POI dataset
   per region (for example from Geofabrik extracts), queried on the device.
   This removes the per-view requests and works offline, but the published
   extract is a derivative database under the ODbL.
3. **Another API** returning OpenStreetMap objects, implemented as a new
   `PlacesRepository`.

## Third-party packages

Flutter packages keep their own licenses (mostly BSD-3-Clause, MIT and
Apache-2.0). The app lists all of them, generated from the build, under
*Impostazioni → Licenze open source*, together with notices for the map data.
Notable native dependencies: MapLibre Native (BSD-2-Clause) and the Google
Play Services location libraries pulled in by `maplibre_gl`.

## Privacy implications

Each external request reveals the user's IP address and the request
contents to the provider. What each service receives is listed in
[PRIVACY.md](../PRIVACY.md).
