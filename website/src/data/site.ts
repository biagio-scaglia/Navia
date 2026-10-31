/** Facts from the Navia repository only. */

export const site = {
  name: 'Navia',
  version: '0.8.0',
  build: '+7',
  status: 'Early development',
  headline: 'Privacy-friendly navigation on OpenStreetMap',
  description:
    'An open-source Android app for maps, search and turn-by-turn guidance. No account, no ads, no analytics—and no Navia backend.',
  github: 'https://github.com/biagio-scaglia/Navia',
  contributing: 'https://github.com/biagio-scaglia/Navia/blob/main/CONTRIBUTING.md',
  privacyMd: 'https://github.com/biagio-scaglia/Navia/blob/main/PRIVACY.md',
  license: 'MIT',
  copyright: '© 2026 Biagio Scaglia',
  coordinates: {
    label: 'Starts in Bari, Italy',
    lat: '41.1258° N',
    lon: '16.8667° E',
  },
} as const

export const nav = [
  { href: '#overview', label: 'Overview' },
  { href: '#features', label: 'Features' },
  { href: '#privacy-promise', label: 'Privacy' },
  { href: '#open-source', label: 'Open Source' },
  { href: '#documentation', label: 'Docs' },
] as const

export const privacyPoints = [
  { icon: 'close' as const, title: 'No account', body: 'Nothing to register. Favorites stay on your phone.' },
  { icon: 'close' as const, title: 'No ads or analytics', body: 'No advertising, analytics or crash SDKs.' },
  { icon: 'locate' as const, title: 'Location on request', body: 'Asked only when you tap. Never in the background.' },
  { icon: 'cloud_off' as const, title: 'No Navia server', body: 'The app talks to open map services only when a feature needs them.' },
] as const

export const features = [
  {
    icon: 'layers' as const,
    title: 'Vector map with real 3D heights',
    body: 'OpenStreetMap through MapLibre. Styles including Essenziale and Navia Notte. Buildings extrude only where OSM has height data.',
  },
  {
    icon: 'directions' as const,
    title: 'Routes and turn-by-turn',
    body: 'Car, bike and walking via OSRM. Italian voice guidance on-device while the app is open, with off-route recalculation.',
  },
  {
    icon: 'search' as const,
    title: 'Search and explore',
    body: 'Photon search, favorites, Wikipedia nearby (Scopri), and 15-minute reachability areas.',
  },
  {
    icon: 'star' as const,
    title: 'OpenStreetMap places',
    body: 'Category filters, place cards from real tags, and optional offline packs for Italian regions.',
  },
  {
    icon: 'shield' as const,
    title: 'Privacy written into the product',
    body: 'In-app policy, no location history, Android cloud backup disabled for app data.',
  },
  {
    icon: 'cube' as const,
    title: 'Built for Bari first',
    body: 'Designed and tested around Bari. The map works worldwide; other regions have had less testing.',
  },
] as const

export const stack = [
  { area: 'UI', value: 'Flutter · Material 3' },
  { area: 'Map', value: 'MapLibre · OpenFreeMap' },
  { area: 'Search', value: 'Photon' },
  { area: 'Routing', value: 'OSRM (FOSSGIS)' },
  { area: 'Places', value: 'Overpass · offline regions' },
  { area: 'License', value: 'MIT · map data ODbL' },
] as const

export const limitations = [
  'Guidance works only with the app open in the foreground.',
  'No live traffic, lane guidance or speed limits.',
  'Offline today covers places you download—not map tiles or routing.',
  'Default public endpoints are for fair, low-volume use.',
] as const

export const docs = [
  {
    icon: 'document' as const,
    title: 'Architecture',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ARCHITECTURE.md',
    body: 'Layers, state and map adapter.',
  },
  {
    icon: 'route' as const,
    title: 'Roadmap',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ROADMAP.md',
    body: 'What shipped and what is next.',
  },
  {
    icon: 'code' as const,
    title: 'Contributing',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/CONTRIBUTING.md',
    body: 'Privacy rules and CI checks.',
  },
  {
    icon: 'globe' as const,
    title: 'Data licenses',
    href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/DATA_LICENSES.md',
    body: 'OSM and related obligations.',
  },
] as const
