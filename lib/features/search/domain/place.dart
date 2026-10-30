import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

/// A geocoding result.
@immutable
class Place {
  const Place({
    required this.name,
    required this.point,
    this.description,
    this.category,
  });

  final String name;

  /// Secondary line, such as street, city and country.
  final String? description;

  final GeoPoint point;

  /// Italian category label, only when the provider reports a known one.
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.name == name &&
      other.description == description &&
      other.category == category &&
      other.point == point;

  @override
  int get hashCode => Object.hash(name, description, category, point);
}
