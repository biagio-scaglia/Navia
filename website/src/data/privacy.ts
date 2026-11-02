/**
 * Testo italiano dell'informativa, identico a lib/core/l10n/privacy_policy.dart
 * (che rispecchia PRIVACY.md): aggiornare i tre insieme.
 */

export const privacyMeta = {
  title: 'Informativa sulla privacy',
  lastUpdated: '31 ottobre 2026',
  lastUpdatedIso: '2026-10-31',
  appliesTo: 'Navia 0.8.0 e successive',
  draftNotice:
    'Bozza in attesa di revisione legale. Descrive il funzionamento reale dell’app, ma non è una certificazione di conformità al GDPR.',
} as const

export const privacySummary = [
  'Nessun account e nessuna registrazione.',
  'Nessuna pubblicità, nessuna analisi statistica, nessun tracciamento.',
  'La posizione si legge solo ad app aperta e solo dopo che la chiedi. Mai in background.',
  'Preferiti e impostazioni restano sul dispositivo e non finiscono nel backup cloud.',
  'Per funzionare, l’app contatta servizi esterni basati su OpenStreetMap. Ricevono solo ciò che serve alla funzione che usi, per esempio le coordinate di partenza e arrivo di un percorso.',
  'Navia non ha un proprio server e non vende i tuoi dati.',
] as const

export type PrivacySection = {
  id: string
  title: string
  paragraphs: string[]
}

export const privacySections: PrivacySection[] = [
  {
    id: 'chi-siamo',
    title: 'Chi siamo',
    paragraphs: [
      'Navia è un’app open source pubblicata su github.com/biagio-scaglia/Navia con licenza MIT. Manutentore: Biagio Scaglia.',
      'Titolare del trattamento: Biagio Scaglia. Contatto privacy: biagio.scaglia01@gmail.com. Per le richieste sulla privacy scrivi a questo indirizzo, non nelle segnalazioni su GitHub, che sono pubbliche.',
      'Navia non ha un server proprio: il manutentore non riceve la tua posizione, le tue ricerche o i tuoi luoghi salvati.',
    ],
  },
  {
    id: 'dati-sul-dispositivo',
    title: 'Dati salvati sul dispositivo',
    paragraphs: [
      'Tema, aspetto della mappa ed edifici 3D: per ricordare le tue scelte.',
      'Preferiti: nome scelto da te, coordinate, data di salvataggio e, se disponibili, categoria, indirizzo e identificativo OpenStreetMap del luogo. Restano consultabili anche offline.',
      'Luoghi offline: i luoghi OpenStreetMap delle zone che scegli di scaricare. Sono dati pubblici della mappa, non dati su di te. Si eliminano da Impostazioni → Luoghi offline.',
      'Questi dati non escono dal dispositivo tramite Navia e sono esclusi dal backup cloud di Android. Si cancellano eliminando i preferiti, svuotando i dati dell’app o disinstallandola.',
      'La posizione non viene salvata: resta in memoria finché l’app è aperta. Anche i risultati di ricerca, i luoghi trovati e i percorsi restano solo in memoria.',
    ],
  },
  {
    id: 'servizi-esterni',
    title: 'Dati inviati a servizi esterni',
    paragraphs: [
      'Ogni richiesta parte direttamente dal tuo dispositivo verso il fornitore, che vede il tuo indirizzo IP e l’ora della richiesta. L’app si identifica come “Navia” con la sua versione, senza identificativi tuoi o del dispositivo.',
      'OpenFreeMap (mappa): riceve la zona e il livello di zoom che stai guardando.',
      'Photon di komoot (ricerca): riceve il testo cercato e una posizione approssimata a circa 1 km, per mostrare prima i risultati vicini. Quando tieni premuto sulla mappa riceve le coordinate esatte di quel punto, per trovarne l’indirizzo.',
      'OSRM sui server FOSSGIS (percorsi): riceve le coordinate di partenza e arrivo e il mezzo scelto. Se parti da “La tua posizione”, la partenza è la posizione del dispositivo.',
      'Overpass API (luoghi): quando scegli una categoria, come “Farmacie”, fuori dalle zone scaricate, riceve la categoria e la zona visualizzata, allargata e arrotondata a circa 1 km. Il server predefinito è overpass-api.de.',
      'Wikipedia (Scopri): solo quando tocchi “Scopri qui intorno”, riceve le coordinate del centro della mappa.',
      'Valhalla sui server FOSSGIS (15 min): solo quando tocchi “Mostra sulla mappa”, riceve il punto di partenza e il mezzo.',
      'Open-Meteo (meteo): quando vedi la scheda di un luogo o il riepilogo di un percorso, riceve la posizione arrotondata a circa 1 km.',
      'Wikipedia e Wikidata: solo quando apri la scheda di un luogo collegato a Wikipedia, ricevono il titolo della voce o il codice Wikidata e la richiesta della sua immagine.',
      'Wikipedia (schede dei luoghi): quando apri la scheda di un luogo con un nome ma senza collegamento a Wikipedia, riceve la posizione arrotondata a circa 100 m e, se vicino c’è una voce con lo stesso nome, il suo titolo e la richiesta della sua immagine.',
      'GitHub e Ministero delle Imprese e del Made in Italy (prezzi carburanti): solo quando confermi il download o l’aggiornamento dei prezzi, GitHub riceve la richiesta del file nazionale dei prezzi; il Ministero riceve la richiesta dei suoi file solo se quello su GitHub non è disponibile o ha più di due giorni.',
      'GitHub (luoghi offline): solo quando apri “Luoghi offline” o confermi il download di una zona, riceve la richiesta dell’elenco o del file della zona scelta.',
      'La zona visualizzata, le ricerche e i punti di un percorso possono rivelare dove sei o dove vai: per questo l’app invia solo il minimo necessario. Ogni fornitore tratta i dati secondo la propria informativa.',
    ],
  },
  {
    id: 'posizione',
    title: 'Posizione del dispositivo',
    paragraphs: [
      'Il permesso di posizione viene chiesto solo quando tocchi il pulsante della posizione o chiedi un percorso da “La tua posizione”. Navia non chiede mai la posizione in background.',
      'Puoi negare il permesso: mappa, ricerca, dettagli dei luoghi e percorsi tra luoghi scelti da te continuano a funzionare.',
      'Puoi revocarlo in qualsiasi momento dalle impostazioni di Android.',
    ],
  },
  {
    id: 'navigazione-guidata',
    title: 'Navigazione guidata',
    paragraphs: [
      'Durante la guida la posizione viene letta di continuo, solo con l’app aperta, per seguirti lungo il percorso. Le istruzioni vocali sono prodotte sul dispositivo dalla sintesi vocale di Android e non vengono inviate a nessuno. Se esci dal percorso, il percorso viene ricalcolato dalla tua posizione al massimo ogni 15 secondi.',
    ],
  },
  {
    id: 'altre-app',
    title: 'Azioni che aprono altre app',
    paragraphs: [
      'Aprire un sito web o un luogo su OpenStreetMap usa il tuo browser. Condividere un luogo apre il menu di condivisione di Android: scegli tu l’app destinataria. Chiamare un numero apre il compositore telefonico, senza avviare la chiamata.',
    ],
  },
  {
    id: 'diritti',
    title: 'I tuoi diritti',
    paragraphs: [
      'Il manutentore non conserva dati personali che ti riguardano: i dati sul dispositivo li gestisci direttamente tu.',
      'Per i dati ricevuti dai servizi esterni puoi esercitare i tuoi diritti (accesso, rettifica, cancellazione, limitazione, opposizione) presso i rispettivi fornitori, e puoi presentare reclamo al Garante per la protezione dei dati personali.',
    ],
  },
  {
    id: 'modifiche',
    title: 'Modifiche',
    paragraphs: [
      'Le modifiche vengono pubblicate nell’app e nel file PRIVACY.md del repository, con una nuova data di aggiornamento.',
    ],
  },
]
