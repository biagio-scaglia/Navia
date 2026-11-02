/** Fatti presi dal repository di Navia: niente promesse oltre ciò che è già nel codice. */

export const site = {
  name: 'Navia',
  version: '0.8.0',
  build: '+7',
  url: 'https://biagio-scaglia.github.io/Navia/',
  title: 'Navia – navigatore open source per Android, senza tracciamento',
  description:
    'Navia è un navigatore gratuito e open source per Android basato su OpenStreetMap: percorsi in auto, bici e a piedi con guida vocale in italiano. Nessun account, nessuna pubblicità, nessun tracciamento.',
  keywords: [
    'navigatore open source',
    'navigatore Android gratis',
    'app mappe senza tracciamento',
    'alternativa open source a Google Maps',
    'OpenStreetMap Android',
    'navigatore privacy',
    'navigatore Bari',
    'guida vocale in italiano',
  ],
  github: 'https://github.com/biagio-scaglia/Navia',
  releases: 'https://github.com/biagio-scaglia/Navia/releases',
  contributing: 'https://github.com/biagio-scaglia/Navia/blob/main/CONTRIBUTING.md',
  privacyMd: 'https://github.com/biagio-scaglia/Navia/blob/main/PRIVACY.md',
  license: 'MIT',
  author: 'Biagio Scaglia',
  year: 2026,
  minAndroid: 'Android 7.0',
  bari: { lat: 41.1258, lon: 16.8667 },
} as const

export const nav = [
  { href: '#funzioni', label: 'Funzioni' },
  { href: '#privacy', label: 'Privacy' },
  { href: '#domande', label: 'Domande' },
  { href: '#sviluppatori', label: 'Sviluppatori' },
] as const

/** Cosa Navia non fa: è la promessa del prodotto. */
export const refusals = [
  { icon: 'shield', title: 'Nessun account', body: 'Non ti registri. I preferiti restano sul telefono.' },
  { icon: 'close', title: 'Nessuna pubblicità', body: 'Nell’app non c’è nessun SDK pubblicitario.' },
  { icon: 'cloud_off', title: 'Nessuna statistica', body: 'Niente analytics, niente crash reporter, niente profilazione.' },
  { icon: 'locate', title: 'Posizione solo se la chiedi', body: 'Con l’app aperta e dopo un tuo tocco. Mai in background.' },
  { icon: 'globe', title: 'Nessun server Navia', body: 'L’app parla solo con servizi aperti, e solo quando una funzione li usa.' },
  { icon: 'star', title: 'Dati sul dispositivo', body: 'Preferiti e impostazioni sono esclusi dal backup cloud di Android.' },
] as const

export type IconName =
  | 'route' | 'shield' | 'search' | 'layers' | 'walk' | 'star' | 'code' | 'document'
  | 'globe' | 'locate' | 'cloud_off' | 'cube' | 'directions' | 'github' | 'external_link'
  | 'check' | 'close'

export const features: {
  id: string
  icon: IconName
  title: string
  lead: string
  points: string[]
}[] = [
  {
    id: 'mappa',
    icon: 'layers',
    title: 'Mappa vettoriale OpenStreetMap con edifici 3D',
    lead:
      'Strade, nomi, quartieri, parchi, acqua e punti di interesse dai dati reali di OpenStreetMap, disegnati con MapLibre.',
    points: [
      'Cinque aspetti: Automatico, Standard, Vivace, Essenziale e Scuro (Navia Notte).',
      'Vista inclinata con edifici 3D presi dalle altezze reali di OSM: dove il dato manca, l’edificio resta piatto.',
      'Cambiando stile restano la visuale, il percorso e i segnaposto.',
    ],
  },
  {
    id: 'navigazione',
    icon: 'directions',
    title: 'Percorsi in auto, bici e a piedi con guida vocale',
    lead:
      'Scegli partenza e arrivo e il percorso compare subito, con distanza, durata e ora di arrivo.',
    points: [
      'Navigazione svolta per svolta con istruzioni vocali in italiano, generate sul telefono dalla sintesi vocale di Android.',
      'Ricalcolo automatico quando esci dal percorso e la visuale che ti segue.',
      'Senza permesso di posizione scegli la partenza dalla ricerca, dalla mappa o dai preferiti.',
    ],
  },
  {
    id: 'ricerca',
    icon: 'search',
    title: 'Ricerca di indirizzi e luoghi mentre scrivi',
    lead:
      'Risultati ordinati intorno alla tua zona, con una posizione arrotondata a circa 1 km.',
    points: [
      'Tieni premuto sulla mappa per scoprire l’indirizzo di un punto qualsiasi.',
      'Preferiti con nome personalizzato, utilizzabili anche offline come partenza o arrivo.',
      'Scopri: le voci di Wikipedia intorno a te, con foto, descrizione e distanza.',
    ],
  },
  {
    id: 'luoghi',
    icon: 'star',
    title: 'Luoghi, carburante e meteo, anche offline',
    lead:
      'Ristoranti, farmacie, spiagge, fontanelle, bancomat e altre categorie, con schede costruite dai tag di OpenStreetMap.',
    points: [
      'Scarica i luoghi di una macroregione italiana: il Sud pesa 3 MB, tutta Italia circa 22 MB.',
      'Prezzi dei carburanti di tutti i distributori italiani dai dati aperti del MIMIT, self e servito.',
      'Area 15 minuti: dove arrivi in 5, 10 e 15 minuti a piedi, in bici o in auto. Meteo da Open-Meteo.',
    ],
  },
]

/** Servizi esterni e dati ricevuti, da PRIVACY.md. */
export const services = [
  { name: 'OpenFreeMap', when: 'Mentre guardi la mappa', what: 'La zona e lo zoom visualizzati' },
  { name: 'Photon (komoot)', when: 'Mentre cerchi, o tenendo premuto sulla mappa', what: 'Il testo cercato e la posizione arrotondata a circa 1 km, oppure il punto premuto' },
  { name: 'OSRM (FOSSGIS)', when: 'Quando calcoli un percorso', what: 'Partenza, arrivo e mezzo scelto' },
  { name: 'Overpass API', when: 'Con una categoria attiva fuori dalle zone scaricate', what: 'Categoria e zona visibile, allargata e arrotondata a circa 1 km' },
  { name: 'Wikipedia', when: 'Quando tocchi Scopri qui intorno o apri una scheda', what: 'Il centro della mappa o il titolo della voce' },
  { name: 'Valhalla (FOSSGIS)', when: 'Quando mostri l’area 15 minuti', what: 'Punto di partenza e mezzo' },
  { name: 'Open-Meteo', when: 'Nelle schede dei luoghi e nel riepilogo del percorso', what: 'La posizione arrotondata a circa 1 km' },
] as const

export const limitations = [
  'La guida funziona solo con l’app aperta in primo piano.',
  'Niente traffico in tempo reale, corsie o limiti di velocità.',
  'Offline oggi ci sono i luoghi che scarichi, non la mappa né i percorsi.',
  'Gli endpoint pubblici predefiniti sono pensati per un uso leggero.',
] as const

export const faq = [
  {
    q: 'Navia è gratis?',
    a: 'Sì. Navia è gratuita e open source con licenza MIT: niente abbonamenti, niente acquisti in app, niente pubblicità.',
  },
  {
    q: 'Navia è un’alternativa a Google Maps?',
    a: 'Vuole diventare un’alternativa leggera alle app di mappe proprietarie per chi non vuole essere tracciato. Oggi offre mappa, ricerca, percorsi e guida vocale, ma non ha ancora traffico in tempo reale, indicazioni di corsia o limiti di velocità.',
  },
  {
    q: 'Quali dati raccoglie Navia?',
    a: 'Nessuno per sé: non ha un server proprio. Preferiti e impostazioni restano sul telefono. Per funzionare l’app contatta servizi basati su OpenStreetMap, che ricevono solo ciò che serve alla funzione che usi, per esempio partenza e arrivo di un percorso.',
  },
  {
    q: 'Serve un account?',
    a: 'No. Non c’è registrazione né login. Apri l’app e la mappa è già lì.',
  },
  {
    q: 'Funziona senza connessione?',
    a: 'In parte. Puoi scaricare i luoghi di una macroregione italiana e i prezzi dei carburanti, e la sintesi vocale funziona offline. La mappa e il calcolo dei percorsi, per ora, richiedono la rete.',
  },
  {
    q: 'Funziona solo a Bari?',
    a: 'No. La mappa copre tutto il mondo. Navia è progettata e provata prima di tutto a Bari, quindi le altre zone sono state testate meno.',
  },
  {
    q: 'Su quali telefoni funziona?',
    a: 'Su Android 7.0 o successivo. Non esiste una versione per iPhone.',
  },
  {
    q: 'Dove scarico Navia?',
    a: 'Un APK pubblico non c’è ancora: Navia è in sviluppo (versione 0.8). Puoi compilarla dal codice sorgente con Flutter o seguire il repository su GitHub per sapere quando esce la prima release.',
  },
] as const

export const stack = [
  { area: 'Interfaccia', value: 'Flutter, Material 3' },
  { area: 'Stato', value: 'Riverpod 3' },
  { area: 'Mappa', value: 'MapLibre Native, OpenFreeMap' },
  { area: 'Ricerca', value: 'Photon' },
  { area: 'Percorsi', value: 'OSRM sui server FOSSGIS' },
  { area: 'Luoghi', value: 'Overpass API e regioni offline' },
  { area: 'Licenza', value: 'MIT, dati mappa ODbL' },
] as const

export const docs = [
  { title: 'Architettura', href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ARCHITECTURE.md', body: 'Livelli, stato e adattatore della mappa' },
  { title: 'Roadmap', href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/ROADMAP.md', body: 'Cosa è uscito e cosa arriva' },
  { title: 'Come contribuire', href: 'https://github.com/biagio-scaglia/Navia/blob/main/CONTRIBUTING.md', body: 'Regole sulla privacy e controlli della CI' },
  { title: 'Licenze dei dati', href: 'https://github.com/biagio-scaglia/Navia/blob/main/docs/DATA_LICENSES.md', body: 'Obblighi di OpenStreetMap e degli altri dati' },
] as const

export const mediaCredits = [
  { title: 'Approaching Bari 114021', creator: 'Quahadi', licence: 'CC BY-SA 4.0', page: 'https://commons.wikimedia.org/wiki/File:Approaching_Bari_114021.webm' },
  { title: 'Porto di Torre a Mare (Bari) 1', creator: 'Driante70', licence: 'CC BY-SA 4.0', page: 'https://commons.wikimedia.org/wiki/File:Porto_di_Torre_a_Mare_(Bari)_1.jpg' },
  { title: 'Bari з вікна Teatro Petruzzelli', creator: 'Map hobby', licence: 'CC BY-SA 4.0', page: 'https://commons.wikimedia.org/wiki/File:Bari_%D0%B7_%D0%B2%D1%96%D0%BA%D0%BD%D0%B0_Teatro_Petruzzelli.jpg' },
  { title: 'Bari BW 2016-10-19 11-55-35', creator: 'Berthold Werner', licence: 'CC BY-SA 3.0', page: 'https://commons.wikimedia.org/wiki/File:Bari_BW_2016-10-19_11-55-35.jpg' },
  { title: 'Panchina sul mar Adriatico in Puglia', creator: 'Piz23', licence: 'CC BY-SA 4.0', page: 'https://commons.wikimedia.org/wiki/File:Panchina-mar-adriatico-Puglia.jpg' },
] as const
