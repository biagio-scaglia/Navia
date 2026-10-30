import 'app_failure.dart';

extension ServiceFailureMessages on ServiceFailure {
  /// Actionable Italian message for users.
  String get message => switch (this) {
    ServiceFailure.noConnection =>
      'Nessuna connessione a internet. Controlla la rete e riprova.',
    ServiceFailure.timeout => 'Il servizio non ha risposto in tempo. Riprova.',
    ServiceFailure.unavailable =>
      'Il servizio non è al momento disponibile. Riprova più tardi.',
    ServiceFailure.rateLimited =>
      'Troppe richieste in poco tempo. Attendi qualche secondo e riprova.',
    ServiceFailure.malformedResponse =>
      'Il servizio ha inviato una risposta non valida. Riprova più tardi.',
    ServiceFailure.noResult => 'Nessun risultato per questa richiesta.',
    ServiceFailure.invalidRequest =>
      'Richiesta non valida. Controlla i dati inseriti.',
    ServiceFailure.notConfigured =>
      'Servizio non configurato in questa versione dell’app.',
  };

  /// Whether retrying the same request may succeed.
  bool get isRetryable => switch (this) {
    ServiceFailure.noResult ||
    ServiceFailure.invalidRequest ||
    ServiceFailure.notConfigured => false,
    _ => true,
  };
}
