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

## Next

### 0.4: Guidance preview

- Step list for the calculated route (OSRM `steps` or Valhalla maneuvers),
  with Italian instruction text
- Recent destinations, stored only on the device
- Profile-mode performance measurements on a mid-range device, documented in
  the repository
- Device testing matrix for small phones, tablets and landscape

### 0.5: Turn-by-turn navigation

- Guidance session with a foreground service and a clear explanation before
  continuous location use
- Off-route detection and automatic rerouting, within provider rate limits
- Optional voice instructions through Android text-to-speech, which works
  offline

### 0.6: Production services

- Documented self-hosting guides for Photon and the routing engine
- Evaluate Valhalla for richer profiles and maneuvers
- Configurable providers per build flavor

## Later

- Offline map regions (PMTiles or MBTiles)
- Offline routing through an on-device engine behind `RoutingRepository`
- Favorites export and import
- Public transport information, where open data allows it
- Accessibility review with TalkBack users
- More languages through ARB-based localization
- F-Droid distribution, which requires removing Google Play Services
  dependencies from the map plugin

## Not planned

- Accounts, cloud sync by default, ads, analytics or location history
  tracking
- A proprietary Navia backend
