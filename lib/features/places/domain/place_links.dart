import '../../../shared/models/geo_point.dart';

/// Validation and formatting of the links a place can open.
///
/// Values come from OpenStreetMap tags written by volunteers, so anything
/// that is not clearly a web address or a phone number is rejected rather
/// than repaired.
abstract final class PlaceLinks {
  /// An http(s) [Uri] for a `website` tag, or null if it is not one.
  ///
  /// A missing scheme is read as https, as is common in the data.
  static Uri? website(String? raw) {
    final value = raw?.split(';').first.trim();
    if (value == null || value.isEmpty || value.contains(' ')) return null;
    final withScheme = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(withScheme);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final host = uri.host;
    if (!host.contains('.') || host.startsWith('.') || host.endsWith('.')) {
      return null;
    }
    return uri;
  }

  /// A dialable number for a `phone` tag, e.g. "+39 080 1234567", or null.
  ///
  /// Only the first of several numbers is kept. The result contains digits,
  /// spaces and an optional leading "+".
  static String? phone(String? raw) {
    final value = raw?.split(RegExp('[;,]')).first.trim();
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9 ()./-]+$').hasMatch(value)) return null;
    final digits = value.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length < 6 || digits.length > 15) return null;
    final readable = value
        .replaceAll(RegExp('[()./-]'), ' ')
        .replaceAll(RegExp(' +'), ' ')
        .trim();
    return readable;
  }

  /// `tel:` link for a number returned by [phone]. It opens the dialer;
  /// the call starts only if the user confirms there.
  static Uri phoneUri(String phone) =>
      Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));

  /// openstreetmap.org link that shows [point] with a marker.
  static Uri mapLink(GeoPoint point) {
    final lat = point.latitude.toStringAsFixed(5);
    final lng = point.longitude.toStringAsFixed(5);
    return Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=18/$lat/$lng',
    );
  }

  /// Text shared through the system share sheet: name, address,
  /// coordinates and a map link.
  static String shareText({
    required GeoPoint point,
    String? name,
    String? address,
  }) => [
    ?name,
    ?address,
    point.toDisplayString(),
    mapLink(point).toString(),
  ].join('\n');
}
