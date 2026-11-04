# Navia roadmap

Milestones are ordered, but dates are not promised. A feature is listed as
done only when it works, has tests, and is documented.

## Done

### 0.1: Foundations

- Flutter project, static analysis, CI (format, analyze, test, APK)
- Design system: color, spacing and radius tokens; light and dark themes;
  Navia logo, launcher icon and icon set
- MapLibre map centered on Bari, with loading, error and retry states
- On-demand location with complete permission handling
- Settings: theme, permission status, online services, attributions,
  licenses, version

### 0.2: Search and routes

- Photon address and place search with debounce, cache and stale-response
  protection
- Long-press point selection with coordinates
- Origin and destination selection, including "La tua posizione", plus swap
  and clear
- OSRM routing by car, bike and on foot, with distance and duration
- Route line and markers drawn by MapLibre layers, with camera framing
- Collapsible navigation panel; the map is never rebuilt by overlay changes
- Reusable service error handling with Italian messages

### 0.3: Map experience and places

- Map appearance selector: Automatico, Standard, Vivace, Essenziale and Scuro
  (OpenFreeMap), with the camera kept across style switches
- Optional 3D buildings from real OpenStreetMap heights, with a tilted camera
- Tapping a point of interest shows its name and an Italian category
- Long-press reverse geocoding through Photon
- Favorites stored on the device: save, rename, delete with undo, and
  duplicate protection
- Search results with category, address and coordinates, plus immediate
  search from the keyboard
- Edge-to-edge system bars that contrast with the map, back gesture
  handling, and a branded splash screen
- Visual refresh: bottom panel docked to the screen edge, controls on one
  axis, Navia back button and icon badges, and automatic route calculation
  with arrival time

### 0.4: Places and privacy

- Draft privacy policy (PRIVACY.md) and in-app privacy screen with a plain
  summary
- Android audit: unused Wi-Fi permission removed, cloud backup disabled
- Real OpenStreetMap places through Overpass, with 13 category filters,
  viewport-based loading, caching and request deduplication
- Place cards with address, opening hours, cuisine, accessibility, phone and
  website, when tagged; share, copy coordinates, call, open website and
  view on OpenStreetMap
- Favorites with OpenStreetMap reference, category and address; route to a
  favorite; favorites as origin or destination in search
- Data licenses and attribution documented
- Offline places for Italy: monthly datasets built in CI from Geofabrik
  extracts, downloaded per macro-region on request, queried on the device

### 0.5: Style and readability

- Navia Notte, a readable night style, and Navia Essenziale, a muted day
  style, both generated from OpenFreeMap Liberty with points of interest
  and 3D buildings
- Category markers with their own colors and icons, and colored columns in
  the 3D view

### 0.6: Richer places

- Wikipedia summary with image in the place card, through Wikidata links
- Italian national holidays in opening hours

### 0.7: Turn-by-turn guidance

- Italian instructions from OSRM maneuvers, with the full step list
- Voice through Android text-to-speech, mute button, screen kept on
- Banner with the next maneuver, camera following the user, arrival time
- Off-route detection and recalculation at most every 15 seconds

### 0.8: Explore

- Bottom panel tabs: Vai, Scopri (Wikipedia nearby) and 15 min (reachable
  areas from Valhalla)
- Weather at places and at the destination (Open-Meteo)
- Fontanelle, Bagni and Spiagge categories
- Daily fuel prices from the Ministry open data, downloaded on request

### 0.9: Background guidance, AMTAB buses and testers' feedback

- `io.github.biagioscaglia.navia.guidance` Kotlin package: a foreground
  service of type location with an ongoing notification of the next
  maneuver and a *Termina* button, so guidance continues with the screen
  locked or in another app, without the background location permission
- Voice instructions on the navigation audio stream, lowering other audio
  while they speak (audio focus with ducking)
- Fuel category from the Ministry registry when prices are downloaded:
  every official station, also those missing from OpenStreetMap
- Favorites on the map as stars, and folders of favorites with their own
  star color
- One *Zone offline* screen for maps and places, with the choice of what
  to download, and a banner on the map when a zone has only one of the two
- Fuel prices in their own settings entry
- AMTAB buses: timetables downloaded from AMTAB and refreshed daily, stops
  on the map, next departures in the stop card (also offline), lines drawn
  in their color with their buses as small 3D models at the scheduled
  position
- Navia's own compass among the map controls, shown only when the map is
  turned, instead of the native one hidden under the overlays
- Still to do: verify background guidance and the fuel price download on
  several real phones

## Next

### 0.10: Offline maps

Implemented, with tests: map regions built monthly in CI with Planetiler
(same OpenMapTiles schema as the current styles), download with consent,
progress and deletion like offline places, offline styles for all four
appearances with bundled fonts and icons. Still to do:

- First run of the `Map data` workflow: build time and file size per region
- Technical trial on a phone, on Bari: `pmtiles://file://` and `asset://`
  resources in MapLibre Android 13.5, offline and in airplane mode
- Navia's 3D buildings in every installed region, not only the first
- Offline search in downloaded places (SQLite)

### 0.11: Public transport

- AMTAB done (see above); still open: AMTAB's license, to publish a
  smaller processed file, and real-time positions from AMTAB's GTFS-RT
  (`avl.amtab.it`, not verified yet)
- Strike notices from the Ministry's register (RSS), with a local
  notification
- Trains: FAL, Ferrotramviaria and Trenitalia from the National Access
  Point (NeTEx), with the same stop card and 3D trains along the tracks

### 0.12: Small improvements

- Marker clustering in dense areas
- Compass heading from the device sensors when walking
- Home screen widget and shortcuts for favorites
- Saved routes, next to saved places

### 1.0: Offline routing and first release

- Technical trial of Valhalla or GraphHopper on Android (data size,
  memory, speed)
- If it works out: offline routes and voice guidance
- Testing on several phones, then the first public release

### Production services

- Documented self-hosting guides for Photon, Overpass and the routing engine
- Offline place datasets for more countries
- Configurable providers per build flavor

## Later

- Android Auto, through the Car App Library
- F-Droid distribution, with a map plugin build without Google Play Services
- Shareable route and place images (MapLibre snapshots)
- Favorites export and import
- Accessibility review with TalkBack users
- More languages through ARB-based localization

## Not planned

- Accounts, cloud sync by default, ads, analytics or location history
  tracking
- A proprietary Navia backend
