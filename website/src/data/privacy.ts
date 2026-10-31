/** English privacy text aligned with PRIVACY.md (draft for legal review). */

export const privacyMeta = {
  title: 'Privacy policy',
  lastUpdated: '31 October 2026',
  appliesTo: 'Navia 0.8.0 and later',
  draftNotice:
    'Draft, prepared for legal review. This document describes how the Navia Android app actually handles data, as implemented in the repository. It has not been reviewed by a lawyer and does not claim certified GDPR compliance.',
} as const

export const privacySummary = [
  'No account, registration or login.',
  'No advertising, analytics or crash-reporting SDKs.',
  'Location is read only while the app is open, and only after you ask. Never in the background.',
  'Favorites and settings stay on the device and are excluded from Android cloud backup.',
  'To work, the app contacts third-party OpenStreetMap-based services. They receive only what each feature needs—for example origin and destination coordinates for a route.',
  'Navia has no server of its own and does not sell your data.',
] as const

export type PrivacySection = {
  title: string
  paragraphs: string[]
}

export const privacySections: PrivacySection[] = [
  {
    title: 'Who we are',
    paragraphs: [
      'Navia is an open-source navigation app published at github.com/biagio-scaglia/Navia under the MIT License. Maintainer: Biagio Scaglia.',
      'Data controller: [TO BE CONFIRMED]. Privacy contact: [TO BE PROVIDED]. Until then, open an issue on GitHub—issues are public, so do not post personal data there.',
      'Navia has no backend of its own. The maintainer does not receive your location, searches or saved places.',
    ],
  },
  {
    title: 'Data kept on your device',
    paragraphs: [
      'Theme, map appearance and 3D buildings setting: to remember your choices.',
      'Favorites: the name you chose, coordinates, the time you saved them and, when available, OpenStreetMap category, address and identifier.',
      'Offline places and fuel prices: public datasets you choose to download. They are map data, not data about you.',
      'This data never leaves the device through Navia. Android cloud backup is disabled (allowBackup=false). Uninstalling or clearing app storage deletes it.',
      'Device location is not stored. It stays in memory while the app is open. Search results, places and routes are kept in memory only and discarded when the app closes.',
    ],
  },
  {
    title: 'Data sent to third-party services',
    paragraphs: [
      'Each request goes from your device to the provider and reveals your IP address and basic technical data. Requests identify the app with a User-Agent such as Navia/<version>; they contain no user or device identifier.',
      'OpenFreeMap: map tiles for the area and zoom you view.',
      'Photon (komoot): search text and an approximate position rounded to about 1 km; or exact coordinates on long-press reverse geocoding.',
      'OSRM (FOSSGIS): origin and destination coordinates and travel mode when a route is calculated.',
      'Overpass API: category and visible area (enlarged and rounded to about 1 km) when a place filter is active outside downloaded regions.',
      'Wikipedia / Wikidata, Valhalla, Open-Meteo, GitHub release assets and MIMIT fuel open data: only when you use the matching feature, as listed in PRIVACY.md.',
      'Providers process data under their own policies, which Navia does not control.',
    ],
  },
  {
    title: 'Device location',
    paragraphs: [
      'Approximate and precise location permission is requested only when you tap the location button or ask for a route from “Your location”. Background location is never requested.',
      'You can deny the permission. Map, search, place details and routes between chosen places still work.',
    ],
  },
  {
    title: 'Turn-by-turn guidance',
    paragraphs: [
      'During guidance, location is read continuously only while the app is open. Voice instructions are produced on-device by Android text-to-speech and are not sent anywhere. Off-route recalculation uses the routing service at most every 15 seconds.',
    ],
  },
  {
    title: 'Your rights',
    paragraphs: [
      'The maintainer holds no personal data about you on a Navia server. You control on-device data directly by deleting favorites, clearing storage or uninstalling.',
      'For data received by third-party providers, exercise your rights with those providers. In Italy you may lodge a complaint with the Garante per la protezione dei dati personali (garanteprivacy.it).',
    ],
  },
  {
    title: 'Changes',
    paragraphs: [
      'Changes are published in PRIVACY.md and in the app, with a new last-updated date. Significant changes, such as a new service receiving data, will be listed in release notes.',
    ],
  },
]
