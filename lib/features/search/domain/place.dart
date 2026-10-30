import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

/// A geocoding result.
@immutable
class Place {
  const Place({required this.name, required this.point, this.description});

  final String name;

  /// Secondary line, such as street, city and country.
  final String? description;

  final GeoPoint point;

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.name == name &&
      other.description == description &&
      other.point == point;

  @override
  int get hashCode => Object.hash(name, description, point);
}
