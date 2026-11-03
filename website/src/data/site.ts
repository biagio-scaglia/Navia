/** Fatti presi dal repository di Navia: niente promesse oltre ciò che è già nel codice. */

export const site = {
  name: 'Navia',
  version: '0.8.1',
  build: '+8',
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
  { href: 'confronto/', label: 'Confronto' },
  { href: '#sviluppatori', label: 'Sviluppatori' },
  { href: 'biagio-scaglia/', label: 'Autore' },
] as const

/** L'autore: solo fatti pubblici dal profilo GitHub. */
export const author = {
  name: 'Biagio Scaglia',
  jobTitle: 'Sviluppatore software e UI/UX designer',
  city: 'Bari',
  region: 'Puglia',
  email: 'biagio.scaglia01@gmail.com',
  github: 'https://github.com/biagio-scaglia',
  linkedin: 'https://www.linkedin.com/in/biagio-scaglia/',
  blog: 'https://biagiocyberspace.it/',
  portfolio: 'https://biagio-scaglia.github.io/',
  skills: [
    { label: 'Flutter', icon: 'si:flutter' },
    { label: 'Dart', icon: 'si:dart' },
    { label: 'TypeScript', icon: 'si:typescript' },
    { label: 'JavaScript', icon: 'si:javascript' },
    { label: 'Astro', icon: 'si:astro' },
    { label: 'C#', icon: 'si:csharp' },
    { label: 'Python', icon: 'si:python' },
    { label: 'Android', icon: 'si:android' },
    { label: 'OpenStreetMap', icon: 'si:openstreetmap' },
    { label: 'MapLibre', icon: 'si:maplibre' },
    { label: 'UI/UX design', icon: 'lucide:pen-tool' },
    { label: 'Sviluppo web', icon: 'lucide:globe' },
  ],
  knowsAbout: [
    'Flutter', 'Dart', 'TypeScript', 'JavaScript', 'Astro', 'C#', 'Python',
    'UI/UX design', 'Sviluppo di app Android', 'Sviluppo web', 'OpenStreetMap', 'MapLibre',
  ],
} as const

export const projects = [
  {
    name: 'Navia',
    href: '',
    tech: 'Flutter, MapLibre',
    body: 'Navigatore open source per Android su OpenStreetMap: percorsi, guida vocale in italiano e nessun tracciamento.',
  },
  {
    name: 'Vellum',
    href: 'https://play.google.com/store/apps/details?id=com.biagioscaglia.vellum',
    tech: 'Flutter, su Google Play',
    body: 'Compagno offline per Dungeons & Dragons: ricerca rapida di mostri e incantesimi, sessioni da pianificare e note locali.',
  },
  {
    name: 'frutiger-js',
    href: 'https://biagio-scaglia.github.io/frutiger-js/',
    tech: 'CSS, TypeScript',
    body: 'Framework CSS ispirato all’estetica Frutiger Aero, per dare ai siti un’aria nostalgica.',
  },
  {
    name: 'KawaiJS',
    href: 'https://biagio-scaglia.github.io/KawaiJS/',
    tech: 'TypeScript',
    body: 'Motore web per visual novel ispirato a Ren’Py, con un linguaggio di scripting dedicato e interfaccia HTML/CSS personalizzabile.',
  },
  {
    name: 'HomuraJS',
    href: 'https://biagio-scaglia.github.io/homura-js/',
    tech: 'TypeScript',
    body: 'Gestione dello stato con cronologia e viaggio nel tempo per applicazioni JavaScript e TypeScript.',
  },
  {
    name: 'Moon-Inferno',
    href: 'https://biagio-scaglia.github.io/moon-inferno/',
    tech: 'TypeScript',
    body: 'Framework UI che mette l’accessibilità al primo posto, senza rinunciare a espressività e prestazioni.',
  },
  {
    name: 'Yumia-MD',
    href: 'https://biagio-scaglia.github.io/Yumia-MD/',
    tech: 'TypeScript',
    body: 'Presentazioni scritte come codice e progettate come componenti, esportabili ovunque.',
  },
  {
    name: 'MangaFlow',
    href: 'https://biagio-scaglia.github.io/manga-flow/',
    tech: 'Flutter',
    body: 'Tracker mobile per le proprie letture manga, con salvataggi che resistono ai crash.',
  },
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
  { name: 'OpenFreeMap', when: 'Mentre guardi la mappa, fuori dalle zone scaricate', what: 'La zona e lo zoom visualizzati' },
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
  'Le mappe offline sono nell’app ma in prova: le zone da scaricare arrivano con la prima pubblicazione dei file.',
  'Offline oggi ci sono i luoghi che scarichi e i prezzi dei carburanti; i percorsi richiedono la rete.',
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
    a: 'In parte. Puoi scaricare i luoghi di una macroregione italiana e i prezzi dei carburanti, e la sintesi vocale funziona offline. Le mappe offline per macroregione sono già nell’app e arrivano con la prima pubblicazione dei file; il calcolo dei percorsi, per ora, richiede la rete.',
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
    a: 'Un APK pubblico non c’è ancora: Navia è in sviluppo (versione 0.8.1). Puoi compilarla dal codice sorgente con Flutter o seguire il repository su GitHub per sapere quando esce la prima release.',
  },
] as const

export const stack = [
  { area: 'Interfaccia', value: 'Flutter, Material 3', icon: 'si:flutter' },
  { area: 'Linguaggio', value: 'Dart, stato con Riverpod 3', icon: 'si:dart' },
  { area: 'Mappa', value: 'MapLibre Native, OpenFreeMap', icon: 'si:maplibre' },
  { area: 'Ricerca', value: 'Photon di komoot', icon: 'si:komoot' },
  { area: 'Percorsi', value: 'OSRM sui server FOSSGIS', icon: 'lucide:route' },
  { area: 'Luoghi', value: 'Overpass API e regioni offline', icon: 'si:openstreetmap' },
  { area: 'Piattaforma', value: 'Android 7.0 o successivo', icon: 'si:android' },
  { area: 'Licenza', value: 'MIT, dati mappa ODbL', icon: 'lucide:scale' },
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
