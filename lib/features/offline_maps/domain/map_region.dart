import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_bounds.dart';

/// A downloadable map of one region: a PMTiles archive of vector tiles in
/// the OpenMapTiles schema, as listed in the catalog published with the app.
@immutable
class MapRegion {
  const MapRegion({
    required this.id,
    required this.name,
    required this.detail,
    required this.file,
    required this.bytes,
    required this.sha256,
    required this.maxZoom,
    required this.bounds,
  });

  final String id;

  /// Italian name, e.g. "Sud".
  final String name;

  /// What the region includes, e.g. "Abruzzo, Molise, Campania, Puglia".
  final String detail;

  /// File name of the archive next to the catalog.
  final String file;

  /// Download size, which is also the size on the device.
  final int bytes;

  /// Lowercase hexadecimal SHA-256 of the archive.
  final String sha256;

  /// Most detailed zoom level of the tiles; the map draws them enlarged
  /// beyond it.
  final int maxZoom;

  final GeoBounds bounds;

  /// Parses a catalog entry, returning null when it is not usable.
  static MapRegion? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final detail = json['detail'];
    final file = json['file'];
    final bytes = json['bytes'];
    final sha256 = json['sha256'];
    final maxZoom = json['maxzoom'];
    final bbox = json['bbox'];
    if (id is! String ||
        !RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(id) ||
        name is! String ||
        file is! String ||
        !RegExp(r'^[A-Za-z0-9._-]{1,80}\.pmtiles$').hasMatch(file) ||
        bytes is! int ||
        bytes <= 0 ||
        sha256 is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        maxZoom is! int ||
        maxZoom < 0 ||
        maxZoom > 22 ||
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
    return MapRegion(
      id: id,
      name: name,
      detail: detail is String ? detail : '',
      file: file,
      bytes: bytes,
      sha256: sha256,
      maxZoom: maxZoom,
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
    'maxzoom': maxZoom,
    'bbox': [bounds.south, bounds.west, bounds.north, bounds.east],
  };

  @override
  bool operator ==(Object other) =>
      other is MapRegion &&
      other.id == id &&
      other.sha256 == sha256 &&
      other.bounds == bounds;

  @override
  int get hashCode => Object.hash(id, sha256, bounds);
}

/// A region whose map is stored on this device.
@immutable
class InstalledMapRegion {
  const InstalledMapRegion({
    required this.region,
    required this.installedAt,
    required this.tilesPath,
  });

  final MapRegion region;
  final DateTime installedAt;

  /// Absolute path of the PMTiles archive on the device.
  final String tilesPath;

  Map<String, Object> toJson() => {
    'region': region.toJson(),
    'installedAt': installedAt.toUtc().toIso8601String(),
  };

  /// Parses `region.json`; [tilesPath] comes from the store, which knows
  /// where the archive is.
  static InstalledMapRegion? tryParse(
    Object? json,
    String Function(MapRegion) tilesPath,
  ) {
    if (json is! Map) return null;
    final region = MapRegion.tryParse(json['region']);
    final installedAt = DateTime.tryParse('${json['installedAt']}');
    if (region == null || installedAt == null) return null;
    return InstalledMapRegion(
      region: region,
      installedAt: installedAt,
      tilesPath: tilesPath(region),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InstalledMapRegion &&
      other.region == region &&
      other.installedAt == installedAt &&
      other.tilesPath == tilesPath;

  @override
  int get hashCode => Object.hash(region, installedAt, tilesPath);
}
