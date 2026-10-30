/// Formats a distance in Italian conventions: "850 m", "1,7 km", "12 km".
String formatDistance(double meters) {
  if (meters < 1000) {
    // Round to 10 m: GPS and routing precision make finer values noise.
    final rounded = (meters / 10).round() * 10;
    return '${rounded < 10 ? meters.round() : rounded} m';
  }
  final km = meters / 1000;
  if (km < 10) {
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${km.round()} km';
}

/// Formats a travel duration: "< 1 min", "12 min", "1 h 05 min", "3 h".
String formatDuration(Duration duration) {
  final minutes = (duration.inSeconds / 60).round();
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours h';
  return '$hours h ${rest.toString().padLeft(2, '0')} min';
}
