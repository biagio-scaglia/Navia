/** Facts taken from the Navia repository. No invented metrics or features. */

export const site = {
  name: 'Navia',
  version: '0.8.0',
  build: '+7',
  status: 'Early development',
  tagline: 'Find your way.',
  description:
    'An open-source, privacy-friendly navigation app for Android. Built with Flutter, MapLibre and OpenStreetMap. No account, no ads, no analytics, and no Navia backend.',
  github: 'https://github.com/biagio-scaglia/Navia',
  docsArchitecture: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ARCHITECTURE.md',
  docsRoadmap: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ROADMAP.md',
  contributing: 'https://github.com/biagio-scaglia/Navia/blob/main/CONTRIBUTING.md',
  privacyMd: 'https://github.com/biagio-scaglia/Navia/blob/main/PRIVACY.md',
  license: 'MIT',
  copyright: '© 2026 Biagio Scaglia',
  // Approximate map centre used by the app (Bari).
  coordinates: {
    label: 'Bari, Italy',
    lat: '41.1258° N',
    lon: '16.8667° E',
    zoom: 'z14',
  },
} as const

export const nav = [
  { href: '#overview', label: 'Overview' },
  { href: '#features', label: 'Features' },
  { href: '#open-source', label: 'Open Source' },
  { href: '#documentation', label: 'Documentation' },
] as const

export const stack = [
  { area: 'UI', value: 'Flutter · Material 3 · custom design system' },
  { area: 'State', value: 'Riverpod 3' },
  { area: 'Map', value: 'MapLibre Native via maplibre_gl' },
  { area: 'Tiles', value: 'OpenFreeMap · OpenMapTiles · OpenStreetMap' },
  { area: 'Search', value: 'Photon (komoot)' },
  { area: 'Routing', value: 'OSRM on FOSSGIS servers' },
  { area: 'Places', value: 'Overpass API · offline regional datasets' },
  { area: 'Reach', value: 'Valhalla isochrones (FOSSGIS)' },
  { area: 'Weather', value: 'Open-Meteo' },
  { area: 'License', value: 'MIT (code) · ODbL (map data)' },
] as const

export const features = [
  {
    id: '01',
    title: 'Vector map, real heights',
    body: 'A fullscreen OpenStreetMap view with styles Automatico, Standard, Vivace, Essenziale and Scuro. Optional 3D buildings extrude only where OpenStreetMap has height data—nothing is invented.',
    note: 'MapLibre · OpenFreeMap',
  },
  {
    id: '02',
    title: 'Routes you ask for',
    body: 'Car, bike and walking routes through OSRM. Turn-by-turn guidance with Italian voice instructions via Android text-to-speech, off-route detection and recalculation—while the app is open.',
    note: 'Foreground guidance only',
  },
  {
    id: '03',
    title: 'Explore in three tabs',
    body: 'Vai for destinations and favorites. Scopri for nearby Wikipedia articles. 15 min for areas reachable in five, ten or fifteen minutes on foot, by bike or by car.',
    note: 'Wikipedia · Valhalla',
  },
  {
    id: '04',
    title: 'Places from the map itself',
    body: 'Filter OpenStreetMap places by category. Cards show opening hours, accessibility, phone and website only when tagged. Offline place packs for Italian macro-regions download on request.',
    note: 'Overpass · Geofabrik extracts',
  },
  {
    id: '05',
    title: 'Privacy by construction',
    body: 'No account. No advertising or analytics SDKs. Location is read only after you ask, only in the foreground. Favorites stay on the device. Android cloud backup is disabled for app data.',
    note: 'See the privacy policy',
  },
] as const

export const principles = [
  {
    title: 'No Navia backend',
    body: 'The app talks directly to replaceable OpenStreetMap-based services. The maintainer does not receive your location, searches or saved places.',
  },
  {
    title: 'Explicit intent',
    body: 'Network and location requests happen after a user action—not on a silent timer in the background.',
  },
  {
    title: 'The renderer is not the product',
    body: 'MapLibre draws. Search, routing and location stay behind interfaces that never import MapLibre types.',
  },
] as const

export const limitations = [
  'Guidance runs only while the app is open in the foreground.',
  'No live traffic, lane guidance or speed limits from the public OSRM server.',
  'Offline support today covers downloaded places, not map tiles or routing.',
  'Default public service endpoints are for fair, low-volume use.',
] as const

export const docs = [
  {
    title: 'Architecture',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ARCHITECTURE.md',
    body: 'Layers, Riverpod state, map adapter and provider choices.',
  },
  {
    title: 'Roadmap',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ROADMAP.md',
    body: 'Shipped milestones through 0.8 and planned offline maps, transit and routing.',
  },
  {
    title: 'Contributing',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/CONTRIBUTING.md',
    body: 'Privacy rules, Conventional Commits, and the checks CI runs.',
  },
  {
    title: 'Data licenses',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/DATA_LICENSES.md',
    body: 'Obligations that come with OpenStreetMap and related datasets.',
  },
] as const
