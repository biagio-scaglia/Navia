import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_bounds.dart';

/// A downloadable dataset of the places of one region, as listed in the
/// catalog published with the app.
@immutable
class PlaceRegion {
  const PlaceRegion({
    required this.id,
    required this.name,
    required this.detail,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.count,
    required this.bounds,
  });

  final String id;

  /// Italian name, e.g. "Sud".
  final String name;

  /// What the region includes, e.g. "Abruzzo, Molise, Campania, Puglia".
  final String detail;

  /// File name of the dataset next to the catalog.
  final String file;

  /// Compressed download size.
  final int bytes;

  /// Lowercase hexadecimal SHA-256 of the download.
  final String sha256;

  /// Number of places.
  final int count;

  final GeoBounds bounds;

  /// Parses a catalog entry, returning null when it is not usable.
  static PlaceRegion? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final detail = json['detail'];
    final file = json['file'];
    final bytes = json['bytes'];
    final sha256 = json['sha256'];
    final count = json['count'];
    final bbox = json['bbox'];
    if (id is! String ||
        !RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(id) ||
        name is! String ||
        file is! String ||
        !RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(file) ||
        bytes is! int ||
        bytes <= 0 ||
        sha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        count is! int ||
        bbox is! List ||
        bbox.length != 4 ||
        bbox.any((value) => value is! num)) {
      return null;
    }
    final bounds = GeoBounds.tryCreate(
      south: (bbox[0] as num).toDouble(),
      west: (bbox[1] as num).toDouble(),
      north: (bbox[2] as num).toDouble(),
      east: (bbox[3] as num).toDouble(),
    );
    if (bounds == null) return null;
    return PlaceRegion(
      id: id,
      name: name,
      detail: detail is String ? detail : '',
      file: file,
      bytes: bytes,
      sha256: sha256,
      count: count,
      bounds: bounds,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'detail': detail,
    'file': file,
    'bytes': bytes,
    'sha256': sha256,
    'count': count,
    'bbox': [bounds.south, bounds.west, bounds.north, bounds.east],
  };

  @override
  bool operator ==(Object other) =>
      other is PlaceRegion &&
      other.id == id &&
      other.sha256 == sha256 &&
      other.bounds == bounds;

  @override
  int get hashCode => Object.hash(id, sha256, bounds);
}

/// A region whose places are stored on this device.
@immutable
class InstalledRegion {
  const InstalledRegion({
    required this.region,
    required this.installedAt,
    required this.bytesOnDisk,
  });

  final PlaceRegion region;
  final DateTime installedAt;

  /// Space used on the device by the extracted data.
  final int bytesOnDisk;

  Map<String, Object> toJson() => {
    'region': region.toJson(),
    'installedAt': installedAt.toUtc().toIso8601String(),
    'bytesOnDisk': bytesOnDisk,
  };

  static InstalledRegion? tryParse(Object? json) {
    if (json is! Map) return null;
    final region = PlaceRegion.tryParse(json['region']);
    final installedAt = DateTime.tryParse('${json['installedAt']}');
    final bytes = json['bytesOnDisk'];
    if (region == null || installedAt == null || bytes is! int) return null;
    return InstalledRegion(
      region: region,
      installedAt: installedAt,
      bytesOnDisk: bytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InstalledRegion &&
      other.region == region &&
      other.installedAt == installedAt &&
      other.bytesOnDisk == bytesOnDisk;

  @override
  int get hashCode => Object.hash(region, installedAt, bytesOnDisk);
}
