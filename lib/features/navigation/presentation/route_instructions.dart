import '../domain/navigation_models.dart';

/// Italian instruction texts for route maneuvers, shown and spoken.
///
/// OSRM sends maneuver types and directions, not text; the phrasing here
/// follows common Italian navigation wording.
abstract final class RouteInstructions {
  static String text(RouteStep step) {
    final street = step.streetName;
    final onto = street == null ? '' : ' in $street';
    final along = street == null ? '' : ' su $street';
    final direction = step.direction;

    return switch (step.kind) {
      ManeuverKind.depart =>
        street == null ? 'Parti seguendo il percorso' : 'Parti su $street',
      ManeuverKind.arrive => 'Sei arrivato a destinazione',
      ManeuverKind.roundabout =>
        step.exit == null
            ? 'Entra nella rotonda'
            : 'Alla rotonda prendi la ${_ordinal(step.exit!)} uscita$onto',
      ManeuverKind.continueStraight || ManeuverKind.newName
          when direction == null || direction == ManeuverDirection.straight =>
        'Continua dritto$along',
      ManeuverKind.fork => '${_keep(direction)}$along',
      ManeuverKind.merge => 'Immettiti$along',
      ManeuverKind.ramp => 'Prendi la rampa${_side(direction)}$onto',
      ManeuverKind.endOfRoad =>
        'Alla fine della strada ${_turn(direction).toLowerCase()}$onto',
      _ => '${_turn(direction)}$onto',
    };
  }

  /// "Tra 200 metri, svolta a destra in Via Sparano".
  static String spokenAhead(RouteStep step, double meters) =>
      'Tra ${spokenDistance(meters)}, ${_lowerFirst(text(step))}';

  /// Distance rounded for speech: "50 metri", "300 metri", "1,5 chilometri".
  static String spokenDistance(double meters) {
    if (meters < 1000) {
      final rounded = meters < 100
          ? (meters / 10).round() * 10
          : (meters / 50).round() * 50;
      return '${rounded < 10 ? 10 : rounded} metri';
    }
    final km = (meters / 100).round() / 10;
    return km == km.roundToDouble()
        ? '${km.round()} ${km == 1 ? 'chilometro' : 'chilometri'}'
        : '${km.toString().replaceAll('.', ',')} chilometri';
  }

  static String _turn(ManeuverDirection? direction) => switch (direction) {
    ManeuverDirection.uturn => 'Fai inversione a U',
    ManeuverDirection.sharpRight => 'Svolta decisamente a destra',
    ManeuverDirection.right => 'Svolta a destra',
    ManeuverDirection.slightRight => 'Tieni la destra',
    ManeuverDirection.slightLeft => 'Tieni la sinistra',
    ManeuverDirection.left => 'Svolta a sinistra',
    ManeuverDirection.sharpLeft => 'Svolta decisamente a sinistra',
    ManeuverDirection.straight || null => 'Prosegui dritto',
  };

  static String _keep(ManeuverDirection? direction) => switch (direction) {
    ManeuverDirection.slightRight ||
    ManeuverDirection.right ||
    ManeuverDirection.sharpRight => 'Al bivio tieni la destra',
    ManeuverDirection.slightLeft ||
    ManeuverDirection.left ||
    ManeuverDirection.sharpLeft => 'Al bivio tieni la sinistra',
    _ => 'Al bivio prosegui dritto',
  };

  static String _side(ManeuverDirection? direction) => switch (direction) {
    ManeuverDirection.slightRight ||
    ManeuverDirection.right ||
    ManeuverDirection.sharpRight => ' a destra',
    ManeuverDirection.slightLeft ||
    ManeuverDirection.left ||
    ManeuverDirection.sharpLeft => ' a sinistra',
    _ => '',
  };

  static String _ordinal(int exit) => switch (exit) {
    1 => 'prima',
    2 => 'seconda',
    3 => 'terza',
    4 => 'quarta',
    5 => 'quinta',
    6 => 'sesta',
    _ => '$exitª',
  };

  static String _lowerFirst(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}
