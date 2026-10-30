import '../../../shared/models/geo_point.dart';
import '../../../shared/models/place_category.dart';
import '../domain/place_links.dart';
import '../domain/poi.dart';

/// Turns OpenStreetMap tags into a [Poi], for Overpass answers and offline
/// datasets alike. Missing or invalid tags are left out, never guessed.
abstract final class OsmPoiParser {
  /// Keeps the non-empty string tags of [raw].
  static Map<String, String> tags(Object? raw) => {
    if (raw is Map)
      for (final MapEntry(:key, :value) in raw.entries)
        if (key is String && value is String && value.trim().isNotEmpty)
          key: value.trim(),
  };

  static Poi fromTags(OsmRef ref, GeoPoint point, Map<String, String> tags) {
    return Poi(
      ref: ref,
      point: point,
      name: tags['name:it'] ?? tags['name'],
      category: PlaceCategory.firstLabel([
        tags['amenity'],
        tags['shop'],
        tags['tourism'],
        tags['leisure'],
        tags['railway'],
        tags['highway'],
      ]),
      address: _address(tags),
      openingHours: tags['opening_hours'],
      website: PlaceLinks.website(tags['website'] ?? tags['contact:website']),
      phone: PlaceLinks.phone(tags['phone'] ?? tags['contact:phone']),
      cuisine: tags['cuisine']
          ?.split(';')
          .map((value) => value.trim().replaceAll('_', ' '))
          .where((value) => value.isNotEmpty)
          .join(', '),
      wheelchair: WheelchairAccess.values.asNameMap()[tags['wheelchair']],
    );
  }

  /// "Via Sparano da Bari, 5 · Bari", from whichever parts are tagged.
  static String? _address(Map<String, String> tags) {
    final street = tags['addr:street'];
    final number = tags['addr:housenumber'];
    final city = tags['addr:city'];
    final line = street == null
        ? null
        : (number == null ? street : '$street, $number');
    final parts = [?line, ?city];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
