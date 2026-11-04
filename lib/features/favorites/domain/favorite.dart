import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';
import '../../places/domain/poi.dart';

/// A place saved by the user on this device.
@immutable
class Favorite {
  const Favorite({
    required this.id,
    required this.name,
    required this.point,
    required this.createdAt,
    this.osmRef,
    this.category,
    this.address,
    this.folderId,
  });

  final String id;

  /// Name chosen by the user.
  final String name;

  final GeoPoint point;
  final DateTime createdAt;

  /// The OpenStreetMap object the place was saved from, if any. It
  /// identifies the same business even if its position is edited.
  final OsmRef? osmRef;

  /// Italian category and address copied from the source data, so that
  /// they stay available offline.
  final String? category;
  final String? address;

  /// The [FavoriteFolder] holding the place; null when it is in none.
  final String? folderId;

  Favorite copyWith({String? name, String? Function()? folderId}) => Favorite(
    id: id,
    name: name ?? this.name,
    point: point,
    createdAt: createdAt,
    osmRef: osmRef,
    category: category,
    address: address,
    folderId: folderId == null ? this.folderId : folderId(),
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'lat': point.latitude,
    'lng': point.longitude,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'osm': ?osmRef?.key,
    'category': ?category,
    'address': ?address,
    'folder': ?folderId,
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
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    return Favorite(
      id: id,
      name: name,
      point: point,
      createdAt: createdAt,
      // Entries saved before these fields existed simply lack them.
      osmRef: OsmRef.tryParse(json['osm']),
      category: text(json['category']),
      address: text(json['address']),
      folderId: text(json['folder']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Favorite &&
      other.id == id &&
      other.name == name &&
      other.point == point &&
      other.createdAt == createdAt &&
      other.osmRef == osmRef &&
      other.category == category &&
      other.address == address &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    point,
    createdAt,
    osmRef,
    category,
    address,
    folderId,
  );
}

/// A folder of favorites, such as "Ristoranti" or "Vacanze 2026". Its pins
/// on the map share one of a few colors.
@immutable
class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.name,
    required this.colorIndex,
  });

  /// Number of folder colors; the index wraps around beyond it.
  static const colorCount = 6;

  final String id;
  final String name;

  /// From 0 to [colorCount] - 1.
  final int colorIndex;

  FavoriteFolder copyWith({String? name}) =>
      FavoriteFolder(id: id, name: name ?? this.name, colorIndex: colorIndex);

  Map<String, Object> toJson() => {'id': id, 'name': name, 'color': colorIndex};

  static FavoriteFolder? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final color = json['color'];
    if (id is! String || name is! String || name.trim().isEmpty) return null;
    return FavoriteFolder(
      id: id,
      name: name,
      colorIndex: color is int ? color % colorCount : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FavoriteFolder &&
      other.id == id &&
      other.name == name &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(id, name, colorIndex);
}
