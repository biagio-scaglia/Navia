import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/geo_bounds.dart';
import '../../../shared/models/geo_point.dart';
import '../domain/place_region.dart';
import '../domain/poi.dart';
import '../domain/poi_category.dart';
import 'osm_poi_parser.dart';

/// Places of downloaded regions, stored in the app's private storage.
///
/// Each region lives in `<root>/<id>/`: `region.json` describes it and
/// `cells/` holds its places split into 0.1 degree cells (about 11 km), one
/// JSON object per line, so that a query reads only the few cells it needs.
/// Import and queries run in a background isolate to keep the map smooth.
class OfflinePlacesStore {
  OfflinePlacesStore(this.root);

  final Directory root;

  /// Cell size in degrees.
  static const cellSize = 0.1;

  static const _regionFile = 'region.json';

  /// Characters kept in memory before writing to the cell files.
  static const _flushThreshold = 8 * 1024 * 1024;
  static const _cellsDir = 'cells';

  /// Regions installed on the device. Incomplete or corrupted ones are
  /// skipped.
  List<InstalledRegion> installed() {
    if (!root.existsSync()) return const [];
    final regions = <InstalledRegion>[];
    for (final entry in root.listSync()) {
      if (entry is! Directory) continue;
      final file = File('${entry.path}/$_regionFile');
      if (!file.existsSync()) continue;
      try {
        final region = InstalledRegion.tryParse(
          jsonDecode(file.readAsStringSync()),
        );
        if (region != null) regions.add(region);
      } on FormatException {
        continue;
      }
    }
    regions.sort((a, b) => a.region.name.compareTo(b.region.name));
    return regions;
  }

  /// Directory for temporary downloads, emptied on deletion.
  Directory get downloads => Directory('${root.path}/.downloads');

  /// Extracts the gzipped dataset [download] of [region] and installs it,
  /// replacing a previous version. The download file is deleted.
  Future<InstalledRegion> install(PlaceRegion region, File download) async {
    final target = Directory('${root.path}/${region.id}');
    final staging = Directory('${root.path}/.staging-${region.id}');
    final downloadPath = download.path;
    final stagingPath = staging.path;
    final bytes = await Isolate.run(
      () => _extract(downloadPath, '$stagingPath/$_cellsDir'),
    );
    final installed = InstalledRegion(
      region: region,
      installedAt: DateTime.now().toUtc(),
      bytesOnDisk: bytes,
    );
    await File(
      '$stagingPath/$_regionFile',
    ).writeAsString(jsonEncode(installed.toJson()), flush: true);
    if (target.existsSync()) await target.delete(recursive: true);
    await staging.rename(target.path);
    if (download.existsSync()) await download.delete();
    return installed;
  }

  Future<void> delete(String regionId) async {
    final target = Directory('${root.path}/$regionId');
    if (target.existsSync()) await target.delete(recursive: true);
  }

  /// Places of [category] inside [bounds] from the installed [regions],
  /// nearest to the center first, at most [limit].
  Future<List<Poi>> query(
    PoiCategory category,
    GeoBounds bounds,
    List<InstalledRegion> regions, {
    required int limit,
  }) {
    final directories = [
      for (final installed in regions)
        if (_intersects(installed.region.bounds, bounds))
          '${root.path}/${installed.region.id}/$_cellsDir',
    ];
    if (directories.isEmpty) return Future.value(const []);
    return Isolate.run(() => _query(directories, category, bounds, limit));
  }

  static bool _intersects(GeoBounds a, GeoBounds b) =>
      a.south <= b.north &&
      a.north >= b.south &&
      a.west <= b.east &&
      a.east >= b.west;

  static String cellKey(double lat, double lon) =>
      '${(lat / cellSize).floor()}_${(lon / cellSize).floor()}';

  /// Splits the dataset into cell files; returns the bytes written.
  static Future<int> _extract(String source, String cellsPath) async {
    final cells = Directory(cellsPath);
    if (cells.existsSync()) await cells.delete(recursive: true);
    await cells.create(recursive: true);

    // Lines are grouped per cell in memory and appended to the cell files
    // in batches, which bounds memory use for large regions.
    final buffers = <String, StringBuffer>{};
    var buffered = 0;
    var bytes = 0;
    Future<void> flush() async {
      for (final MapEntry(:key, :value) in buffers.entries) {
        final content = utf8.encode(value.toString());
        bytes += content.length;
        await File(
          '$cellsPath/$key.jsonl',
        ).writeAsBytes(content, mode: FileMode.append);
      }
      buffers.clear();
      buffered = 0;
    }

    final lines = File(source)
        .openRead()
        .transform(gzip.decoder)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) continue;
      final Object? json;
      try {
        json = jsonDecode(line);
      } on FormatException {
        continue;
      }
      if (json is! Map) continue;
      final lat = json['lat'];
      final lon = json['lon'];
      if (lat is! num || lon is! num) continue;
      buffers
          .putIfAbsent(
            cellKey(lat.toDouble(), lon.toDouble()),
            StringBuffer.new,
          )
          .writeln(line);
      buffered += line.length;
      if (buffered > _flushThreshold) await flush();
    }
    await flush();
    return bytes;
  }

  static List<Poi> _query(
    List<String> directories,
    PoiCategory category,
    GeoBounds bounds,
    int limit,
  ) {
    final south = (bounds.south / cellSize).floor();
    final north = (bounds.north / cellSize).floor();
    final west = (bounds.west / cellSize).floor();
    final east = (bounds.east / cellSize).floor();

    final places = <String, Poi>{};
    for (final directory in directories) {
      for (var row = south; row <= north; row++) {
        for (var column = west; column <= east; column++) {
          final file = File('$directory/${row}_$column.jsonl');
          if (!file.existsSync()) continue;
          for (final line in file.readAsLinesSync()) {
            final poi = _parse(line, category, bounds);
            if (poi != null) places[poi.ref.key] = poi;
          }
        }
      }
    }

    final center = bounds.center;
    final sorted = places.values.toList()
      ..sort(
        (a, b) =>
            a.point.distanceTo(center).compareTo(b.point.distanceTo(center)),
      );
    return sorted.take(limit).toList();
  }

  static Poi? _parse(String line, PoiCategory category, GeoBounds bounds) {
    if (line.isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final ref = OsmRef.tryParse(json['id']);
    final lat = json['lat'];
    final lon = json['lon'];
    final point = GeoPoint.tryCreate(
      lat is num ? lat : null,
      lon is num ? lon : null,
    );
    if (ref == null || point == null || !bounds.containsPoint(point)) {
      return null;
    }
    final tags = OsmPoiParser.tags(json['tags']);
    if (!category.matches(tags)) return null;
    return OsmPoiParser.fromTags(ref, point, tags);
  }
}

/// Where downloaded place data is stored; set at startup.
final placesDataDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError(
    'placesDataDirectoryProvider must be overridden at startup',
  ),
);

final offlinePlacesStoreProvider = Provider<OfflinePlacesStore>(
  (ref) => OfflinePlacesStore(ref.watch(placesDataDirectoryProvider)),
);
