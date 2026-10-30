import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

/// A place saved by the user on this device.
@immutable
class Favorite {
  const Favorite({
    required this.id,
    required this.name,
    required this.point,
    required this.createdAt,
  });

  final String id;

  /// Name chosen by the user.
  final String name;

  final GeoPoint point;
  final DateTime createdAt;

  Favorite copyWith({String? name}) => Favorite(
    id: id,
    name: name ?? this.name,
    point: point,
    createdAt: createdAt,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'lat': point.latitude,
    'lng': point.longitude,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Parses a stored favorite, returning null for corrupted entries.
  static Favorite? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final lat = json['lat'];
    final lng = json['lng'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final point = GeoPoint.tryCreate(
      lat is num ? lat : null,
      lng is num ? lng : null,
    );
    if (id is! String ||
        name is! String ||
        name.trim().isEmpty ||
        point == null ||
        createdAt == null) {
      return null;
    }
    return Favorite(id: id, name: name, point: point, createdAt: createdAt);
  }

  @override
  bool operator ==(Object other) =>
      other is Favorite &&
      other.id == id &&
      other.name == name &&
      other.point == point &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, point, createdAt);
}
