/// User-facing copy. Navia is Italian-only for now.
///
/// Keeping every string here makes a later move to ARB-based localization
/// (`flutter gen-l10n`) a mechanical change.
abstract final class AppStrings {
  // Map screen.
  static const settings = 'Impostazioni';
  static const zoomIn = 'Aumenta zoom';
  static const zoomOut = 'Riduci zoom';
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
  static const privacy = 'Privacy';
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
}
