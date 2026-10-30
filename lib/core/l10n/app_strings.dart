/// User-facing copy. Navia is Italian-only for now.
///
/// Keeping every string here makes a later move to ARB-based localization
/// (`flutter gen-l10n`) a mechanical change.
abstract final class AppStrings {
  // Map screen.
  static const settings = 'Impostazioni';
  static const mapLoading = 'Caricamento mappa…';
  static const mapErrorTitle = 'Mappa non disponibile';
  static const mapErrorBody =
      'Non è stato possibile caricare la mappa. Controlla la connessione '
      'a internet e riprova.';
  static const retry = 'Riprova';
  static const mapAttribution = 'Attribuzioni della mappa';
  static const mapAttributionShort = '© OpenStreetMap';

  // Location.
  static const showMyLocation = 'Mostra la mia posizione';
  static const centerOnMyLocation = 'Centra sulla mia posizione';
  static const locating = 'Ricerca della posizione…';
  static const locationServiceDisabled =
      'La localizzazione del dispositivo è disattivata.';
  static const locationPermissionDenied =
      'Permesso di posizione negato. Puoi continuare a usare la mappa.';
  static const locationPermissionDeniedForever =
      'Il permesso di posizione è bloccato. Puoi abilitarlo dalle '
      'impostazioni dell’app.';
  static const locationUnavailable =
      'Impossibile determinare la posizione. Riprova tra qualche istante.';
  static const enable = 'Attiva';
  static const openSettings = 'Impostazioni';

  // Settings screen.
  static const appearance = 'Aspetto';
  static const theme = 'Tema';
  static const themeSystem = 'Sistema';
  static const themeLight = 'Chiaro';
  static const themeDark = 'Scuro';
  static const location = 'Posizione';
  static const locationInfo =
      'Navia usa la posizione solo mentre l’app è aperta e solo dopo che '
      'tocchi il pulsante della posizione. La posizione non viene salvata '
      'né inviata a nessun server.';
  static const locationStatus = 'Stato del permesso';
  static const locationGranted = 'Consentito';
  static const locationDenied = 'Non concesso';
  static const locationDeniedForever = 'Bloccato';
  static const locationStatusUnknown = 'Non disponibile';
  static const manageInSystemSettings =
      'Gestisci nelle impostazioni di sistema';
  static const map = 'Mappa';
  static const mapProvider = 'Fornitore della mappa';
  static const mapDataNotice =
      'I dati della mappa provengono da OpenStreetMap e sono disponibili con '
      'licenza Open Database License (ODbL).';
  static const about = 'Informazioni';
  static const privacyPolicy = 'Informativa sulla privacy';
  static const privacySummary = 'In breve';
  static const privacyPolicyOnline = 'Leggi su GitHub';
  static const lastUpdated = 'Ultimo aggiornamento';
  static const privacyInfo =
      'Nessun account, nessuna pubblicità, nessuna analisi. Le preferenze '
      'restano sul dispositivo. Per mostrare la mappa, l’app scarica i dati '
      'dal fornitore della mappa.';
  static const sourceCode = 'Codice sorgente';
  static const openSourceLicenses = 'Licenze open source';
  static const version = 'Versione';
  static const linkOpenError = 'Impossibile aprire il collegamento.';
  static const appLegalese =
      'Software libero rilasciato con licenza MIT.\n'
      'Dati della mappa © OpenStreetMap contributors.';

  // Search.
  static const searchHint = 'Cerca un luogo o un indirizzo';
  static const searchOriginHint = 'Cerca la partenza';
  static const searchDestinationHint = 'Cerca la destinazione';
  static const searchIdle = 'Digita almeno 3 caratteri per cercare.';
  static const searchLongPressTip =
      'Puoi anche tenere premuto sulla mappa per scegliere un punto.';
  static const searchAttribution = 'Ricerca con Photon · Dati © OpenStreetMap';
  static const clearSearch = 'Cancella';
  static const searchUnavailable =
      'La ricerca non è configurata in questa versione dell’app.';
  static String searchEmpty(String query) =>
      'Nessun risultato per “$query”. Prova con un indirizzo più completo.';

  // Navigation.
  static const whereTo = 'Dove vuoi andare?';
  static const directions = 'Indicazioni';
  static const origin = 'Partenza';
  static const destination = 'Destinazione';
  static const yourLocation = 'La tua posizione';
  static const mapPoint = 'Punto sulla mappa';
  static const selectedPoint = 'Punto selezionato';
  static const chooseOrigin = 'Scegli la partenza';
  static const chooseDestination = 'Scegli la destinazione';
  static const swapWaypoints = 'Inverti partenza e destinazione';
  static const calculateRoute = 'Calcola percorso';
  static const calculatingRoute = 'Calcolo del percorso…';
  static const routeUnavailable = 'Percorso non disponibile';
  static const closeRoute = 'Chiudi percorso';
  static const close = 'Chiudi';
  static const back = 'Indietro';

  // Place details.
  static const openingHours = 'Orari';
  static const openNow = 'Aperto ora';
  static const closedNow = 'Chiuso ora';
  static const cuisine = 'Cucina';
  static const accessibility = 'Accessibilità';
  static const wheelchairYes = 'Accessibile in sedia a rotelle';
  static const wheelchairLimited = 'Accessibilità limitata';
  static const wheelchairNo = 'Non accessibile in sedia a rotelle';
  static const phone = 'Telefono';
  static const call = 'Chiama';
  static const website = 'Sito web';
  static const openWebsite = 'Apri il sito web';
  static const placeDataSource = 'Dati © OpenStreetMap';
  static const viewOnOpenStreetMap = 'Vedi su OpenStreetMap';
  static const share = 'Condividi';
  static const shareFailed = 'Impossibile condividere il luogo.';
  static const copyCoordinates = 'Copia coordinate';
  static const coordinatesCopied = 'Coordinate copiate.';

  // Place discovery.
  static const clearFilter = 'tocca per rimuovere il filtro';
  static const placesLoading = 'Ricerca dei luoghi in quest’area…';
  static const placesZoomIn = 'Avvicina la mappa per vedere i luoghi.';
  static const placesUnavailable = 'Luoghi non disponibili.';
  static String placesEmpty(String category) =>
      'Nessun risultato in quest’area per “$category”.';
  static String placesFound(int count) =>
      count == 1 ? '1 luogo in quest’area' : '$count luoghi in quest’area';
  static const appTagline = 'Mappe libere, senza tracciamento.';
  static const startHere = 'Parti da qui';
  static const routeHint =
      'Scegli partenza e destinazione: il percorso si calcola da solo.';
  static String arrivalAt(String time) => 'Arrivo alle $time';
  static const showWholeRoute = 'Mostra tutto il percorso';
  static const expandSheet = 'Espandi';
  static const collapseSheet = 'Riduci';
  static const modeDriving = 'Auto';
  static const modeCycling = 'Bici';
  static const modeWalking = 'A piedi';
  static const samePoints = 'Partenza e destinazione coincidono.';
  static const noRoute =
      'Nessun percorso trovato tra i due punti con questo mezzo.';
  static const routingDisabled =
      'Il calcolo dei percorsi non è configurato in questa versione.';
  static const routeEstimateNote =
      'Tempi stimati, senza traffico in tempo reale.';
  static const routeAttribution = 'Percorso: OSRM (FOSSGIS) · © OpenStreetMap';
  static const reportMapIssue = 'Segnala un errore nella mappa';

  // Online services (settings).
  static const onlineServices = 'Servizi online';
  static const onlineServicesInfo =
      'Navia non ha un proprio server. Queste richieste partono solo quando '
      'usi la funzione corrispondente:';
  static const serviceMap = 'Mappa: OpenFreeMap';
  static const serviceMapDetail = 'Riceve la zona di mappa visualizzata.';
  static const serviceSearch = 'Ricerca: Photon (komoot)';
  static const serviceSearchDetail =
      'Riceve il testo cercato, una posizione approssimata (circa 1 km) e '
      'i punti che tieni premuti sulla mappa, per trovarne l’indirizzo.';
  static const serviceRouting = 'Percorsi: OSRM (FOSSGIS)';
  static const serviceRoutingDetail =
      'Riceve le coordinate di partenza e destinazione.';

  // Common actions.
  static const cancel = 'Annulla';
  static const save = 'Salva';
  static const undo = 'Annulla';
  static const rename = 'Rinomina';
  static const delete = 'Elimina';

  // Map appearance and 3D.
  static const mapAppearance = 'Aspetto della mappa';
  static const appearanceAutomatic = 'Automatico';
  static const appearanceAutomaticDetail = 'Segue il tema dell’app';
  static const appearanceStandard = 'Standard';
  static const appearanceStandardDetail =
      'Strade, edifici e punti di interesse';
  static const appearanceVivid = 'Vivace';
  static const appearanceVividDetail = 'Colori più marcati';
  static const appearanceMinimal = 'Essenziale';
  static const appearanceMinimalDetail = 'Pochi dettagli, percorsi in evidenza';
  static const appearanceDark = 'Scuro';
  static const appearanceDarkDetail = 'Per la notte';
  static const buildings3d = 'Edifici 3D';
  static const buildings3dDetail =
      'Inclina la mappa e mostra gli edifici con la loro altezza reale, '
      'dove il dato è disponibile in OpenStreetMap.';
  static const buildings3dUnavailable =
      'Il fornitore della mappa non offre l’altezza degli edifici.';
  static const enable3d = 'Attiva vista 3D';
  static const disable3d = 'Disattiva vista 3D';

  // Selection.
  static const lookingUpAddress = 'Ricerca dell’indirizzo…';
  static const addressUnavailable = 'Indirizzo non disponibile';
  static const coordinates = 'Coordinate';

  // Favorites.
  static const favorites = 'Preferiti';
  static const saveFavorite = 'Salva nei preferiti';
  static const savedFavorite = 'Salvato nei preferiti';
  static const favoriteName = 'Nome';
  static const favoriteDefaultName = 'Luogo salvato';
  static const renameFavorite = 'Rinomina preferito';
  static String favoriteSaved(String name) => '“$name” salvato nei preferiti.';
  static String favoriteExists(String name) =>
      'Questo luogo è già nei preferiti come “$name”.';
  static String favoriteDeleted(String name) => '“$name” eliminato.';
  static const favoritesEmptyTitle = 'Nessun preferito';
  static const favoritesEmptyBody =
      'Seleziona un luogo sulla mappa o nella ricerca e tocca la stella per '
      'salvarlo. I preferiti restano solo su questo dispositivo.';

  // Search results.
  static const searchSubmit = 'Cerca';
}
