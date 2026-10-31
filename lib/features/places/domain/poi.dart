import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

enum OsmElementType { node, way, relation }

/// Stable identifier of an OpenStreetMap object.
@immutable
class OsmRef {
  const OsmRef(this.type, this.id);

  final OsmElementType type;
  final int id;

  /// Compact form used in map features and storage, e.g. "node/123".
  String get key => '${type.name}/$id';

  /// The object's page on openstreetmap.org.
  Uri get url => Uri.parse('https://www.openstreetmap.org/$key');

  static OsmRef? tryParse(Object? key) {
    if (key is! String) return null;
    final parts = key.split('/');
    if (parts.length != 2) return null;
    final type = OsmElementType.values.asNameMap()[parts[0]];
    final id = int.tryParse(parts[1]);
    if (type == null || id == null || id <= 0) return null;
    return OsmRef(type, id);
  }

  @override
  bool operator ==(Object other) =>
      other is OsmRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => key;
}

/// Wheelchair access as tagged in OpenStreetMap (`wheelchair=*`).
enum WheelchairAccess { yes, limited, no }

/// A point of interest from OpenStreetMap, with the details its tags carry.
///
/// Every detail is optional and copied from the source data: Navia never
/// fills a missing value with a guess.
@immutable
class Poi {
  const Poi({
    required this.ref,
    required this.point,
    this.name,
    this.category,
    this.address,
    this.openingHours,
    this.website,
    this.phone,
    this.cuisine,
    this.wheelchair,
    this.wikidata,
    this.wikipedia,
  });

  final OsmRef ref;

  /// Location of a node, or the center of a way or relation.
  final GeoPoint point;

  /// The `name` tag (or `name:it`).
  final String? name;

  /// Italian label of the main tag value, e.g. "Farmacia".
  final String? category;

  /// Street, house number and city, from `addr:*` tags.
  final String? address;

  /// The raw `opening_hours` value.
  final String? openingHours;

  /// A validated http(s) link from `website` or `contact:website`.
  final Uri? website;

  /// A validated dialable number from `phone` or `contact:phone`.
  final String? phone;

  /// Readable `cuisine` values, e.g. "pizza, italian".
  final String? cuisine;

  final WheelchairAccess? wheelchair;

  /// Wikidata item id, e.g. "Q1234", from the `wikidata` tag.
  final String? wikidata;

  /// Wikipedia article as "language:Title", from the `wikipedia` tag.
  final String? wikipedia;

  @override
  bool operator ==(Object other) =>
      other is Poi &&
      other.ref == ref &&
      other.point == point &&
      other.name == name &&
      other.category == category &&
      other.address == address &&
      other.openingHours == openingHours &&
      other.website == website &&
      other.phone == phone &&
      other.cuisine == cuisine &&
      other.wheelchair == wheelchair &&
      other.wikidata == wikidata &&
      other.wikipedia == wikipedia;

  @override
  int get hashCode => Object.hash(
    ref,
    point,
    name,
    category,
    address,
    openingHours,
    website,
    phone,
    cuisine,
    wheelchair,
    wikidata,
    wikipedia,
  );
}
