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

## Next

### 0.9: Offline maps

- Check PMTiles support in the MapLibre version in use
- Map regions built in CI and downloaded with consent, progress and deletion

### 0.10: Public transport

- Open GTFS timetables, starting from Bari and Puglia, prepared in CI
- Stops with lines and next scheduled departures, also offline

### 1.0: Offline routing (experimental)

- Technical trial of Valhalla on Android (data size, memory, speed)
- If it works out: offline routes and voice guidance

### Production services

- Documented self-hosting guides for Photon, Overpass and the routing engine
- Offline place datasets for more countries
- Evaluate Valhalla for richer profiles and maneuvers
- Configurable providers per build flavor

## Later

- Favorites export and import
- Accessibility review with TalkBack users
- More languages through ARB-based localization
- F-Droid distribution, which requires removing Google Play Services
  dependencies from the map plugin

## Not planned

- Accounts, cloud sync by default, ads, analytics or location history
  tracking
- A proprietary Navia backend
