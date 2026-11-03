/**
 * Confronto tra navigatori. Solo voci verificabili; quando un dato cambia, aggiornare
 * `compareMeta.checked`. "yes" / "no" / "partial" scelgono l'icona, `note` la spiega.
 */

export const compareMeta = {
  checked: 'novembre 2026',
  checkedIso: '2026-11-03',
} as const

export const apps = [
  { id: 'navia', name: 'Navia', icon: null, url: '' },
  { id: 'google', name: 'Google Maps', icon: 'si:googlemaps', url: 'https://www.google.com/maps' },
  { id: 'organic', name: 'Organic Maps', icon: 'si:organicmaps', url: 'https://organicmaps.app/' },
  { id: 'osmand', name: 'OsmAnd', icon: 'si:osmand', url: 'https://osmand.net/' },
] as const

type Cell = { v: 'yes' | 'no' | 'partial'; note: string }
type Row = { label: string; cells: Record<(typeof apps)[number]['id'], Cell> }

export const rows: Row[] = [
  {
    label: 'Codice open source',
    cells: {
      navia: { v: 'yes', note: 'Licenza MIT' },
      google: { v: 'no', note: 'Proprietario' },
      organic: { v: 'yes', note: 'Licenza Apache 2.0' },
      osmand: { v: 'yes', note: 'Licenza GPLv3' },
    },
  },
  {
    label: 'Dati della mappa aperti',
    cells: {
      navia: { v: 'yes', note: 'OpenStreetMap' },
      google: { v: 'no', note: 'Dati proprietari di Google' },
      organic: { v: 'yes', note: 'OpenStreetMap' },
      osmand: { v: 'yes', note: 'OpenStreetMap' },
    },
  },
  {
    label: 'Si usa senza account',
    cells: {
      navia: { v: 'yes', note: 'Non esiste un account' },
      google: { v: 'partial', note: 'Sì, ma molte funzioni chiedono l’account Google' },
      organic: { v: 'yes', note: 'Non esiste un account' },
      osmand: { v: 'yes', note: 'Account facoltativo per il cloud' },
    },
  },
  {
    label: 'Gratuito',
    cells: {
      navia: { v: 'yes', note: 'Tutto gratis' },
      google: { v: 'yes', note: 'Gratis, con contenuti sponsorizzati' },
      organic: { v: 'yes', note: 'Tutto gratis, sostenuto da donazioni' },
      osmand: { v: 'partial', note: 'Versione gratuita con limiti, funzioni a pagamento' },
    },
  },
  {
    label: 'Navigazione vocale',
    cells: {
      navia: { v: 'yes', note: 'In italiano, con l’app aperta' },
      google: { v: 'yes', note: 'Sì' },
      organic: { v: 'yes', note: 'Sì' },
      osmand: { v: 'yes', note: 'Sì' },
    },
  },
  {
    label: 'Mappe offline',
    cells: {
      navia: { v: 'partial', note: 'Luoghi e prezzi dei carburanti; mappa offline in arrivo' },
      google: { v: 'yes', note: 'Aree scaricabili' },
      organic: { v: 'yes', note: 'Pensata per l’uso offline' },
      osmand: { v: 'yes', note: 'Mappe e percorsi offline' },
    },
  },
  {
    label: 'Traffico in tempo reale',
    cells: {
      navia: { v: 'no', note: 'No' },
      google: { v: 'yes', note: 'Sì' },
      organic: { v: 'no', note: 'No' },
      osmand: { v: 'no', note: 'No' },
    },
  },
  {
    label: 'Prezzi dei carburanti italiani',
    cells: {
      navia: { v: 'yes', note: 'Tutti i distributori, dai dati aperti del MIMIT' },
      google: { v: 'partial', note: 'Per alcuni distributori' },
      organic: { v: 'no', note: 'No' },
      osmand: { v: 'no', note: 'No' },
    },
  },
  {
    label: 'iPhone',
    cells: {
      navia: { v: 'no', note: 'Solo Android' },
      google: { v: 'yes', note: 'Android, iPhone e web' },
      organic: { v: 'yes', note: 'Android e iPhone' },
      osmand: { v: 'yes', note: 'Android e iPhone' },
    },
  },
]

export const verdicts = [
  {
    title: 'Scegli Navia se…',
    body: 'vuoi un navigatore semplice, in italiano, che non sa chi sei: niente account, niente statistiche, nessun server dello sviluppatore. E se ti servono i prezzi dei carburanti in Italia.',
  },
  {
    title: 'Scegli Organic Maps se…',
    body: 'ti serve la mappa completamente offline oggi, anche su iPhone, con la stessa attenzione alla privacy.',
  },
  {
    title: 'Scegli OsmAnd se…',
    body: 'vuoi tutto configurabile: mappe offline dettagliate, curve di livello, tracce GPX e molti plugin.',
  },
  {
    title: 'Resta su Google Maps se…',
    body: 'il traffico in tempo reale e le indicazioni di corsia contano più della privacy.',
  },
] as const
