import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_region.dart';

/// Maps of downloaded regions, stored in the app's private storage.
///
/// Each region lives in `<root>/<id>/`: `region.json` describes it and
/// `map-<checksum>.pmtiles` holds its tiles. The checksum in the name gives
/// every version its own path, so the map reloads the tiles after an
/// update instead of reading a replaced file through a stale index.
class OfflineMapsStore {
  OfflineMapsStore(this.root);

  final Directory root;

  static const _regionFile = 'region.json';

  /// Regions installed on the device. Incomplete or corrupted ones are
  /// skipped.
  List<InstalledMapRegion> installed() {
    if (!root.existsSync()) return const [];
    final regions = <InstalledMapRegion>[];
    for (final entry in root.listSync()) {
      if (entry is! Directory) continue;
      final file = File('${entry.path}/$_regionFile');
      if (!file.existsSync()) continue;
      try {
        final region = InstalledMapRegion.tryParse(
          jsonDecode(file.readAsStringSync()),
          tilesPath,
        );
        if (region != null && File(region.tilesPath).existsSync()) {
          regions.add(region);
        }
      } on FormatException {
        continue;
      }
    }
    regions.sort((a, b) => a.region.name.compareTo(b.region.name));
    return regions;
  }

  /// Directory for temporary downloads.
  Directory get downloads => Directory('${root.path}/.downloads');

  /// Where the archive of [region] is stored once installed.
  String tilesPath(MapRegion region) =>
      '${root.path}/${region.id}/${_tilesFile(region)}';

  static String _tilesFile(MapRegion region) =>
      'map-${region.sha256.substring(0, 12)}.pmtiles';

  /// Installs the verified archive [download] of [region], replacing a
  /// previous version. The download is moved, not copied.
  Future<InstalledMapRegion> install(MapRegion region, File download) async {
    final target = Directory('${root.path}/${region.id}');
    final staging = Directory('${root.path}/.staging-${region.id}');
    if (staging.existsSync()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    await download.rename('${staging.path}/${_tilesFile(region)}');
    final installed = InstalledMapRegion(
      region: region,
      installedAt: DateTime.now().toUtc(),
      tilesPath: tilesPath(region),
    );
    await File(
      '${staging.path}/$_regionFile',
    ).writeAsString(jsonEncode(installed.toJson()), flush: true);
    if (target.existsSync()) await target.delete(recursive: true);
    await staging.rename(target.path);
    return installed;
  }

  Future<void> delete(String regionId) async {
    final target = Directory('${root.path}/$regionId');
    if (target.existsSync()) await target.delete(recursive: true);
  }
}

/// Where downloaded maps are stored; set at startup.
final mapsDataDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError(
    'mapsDataDirectoryProvider must be overridden at startup',
  ),
);

final offlineMapsStoreProvider = Provider<OfflineMapsStore>(
  (ref) => OfflineMapsStore(ref.watch(mapsDataDirectoryProvider)),
);
