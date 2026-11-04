import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../shared/models/geo_point.dart';
import '../../places/data/offline_places_store.dart';
import '../../places/data/place_data_client.dart';
import '../domain/schedule.dart';
import '../domain/transit.dart';
import 'gtfs_import.dart';
import 'zip_reader.dart';

/// Downloads AMTAB's GTFS timetables straight from AMTAB and keeps them,
/// processed into small files, in private app storage.
class TransitStore {
  TransitStore(this.root, this._http, {required this.url});

  final Directory root;
  final http.Client _http;
  final Uri url;

  /// No progress for this long aborts the download.
  static const _stallTimeout = Duration(seconds: 30);

  /// The feed is a few MB: anything far larger is wrong.
  static const _maxDownload = 60 * 1024 * 1024;

  Directory get _directory => Directory('${root.path}/transit/amtab');
  Directory get _staging => Directory('${root.path}/transit/amtab.staging');
  File get _info => File('${_directory.path}/info.json');

  TransitInfo? info() {
    if (!_info.existsSync()) return null;
    try {
      return TransitInfo.tryParse(jsonDecode(_info.readAsStringSync()));
    } on FormatException {
      return null;
    }
  }

  /// Downloads the feed, processes it on a background isolate and replaces
  /// the installed timetables only when everything succeeded.
  Future<TransitInfo> download({
    required String userAgent,
    void Function(int received, int? total)? onProgress,
    void Function()? onProcessing,
    bool Function()? isCancelled,
  }) async {
    await root.create(recursive: true);
    final zip = File('${root.path}/transit/amtab.zip.download');
    await zip.parent.create(recursive: true);
    try {
      await _fetch(
        zip,
        userAgent: userAgent,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      onProcessing?.call();
      final (zipPath, stagingPath) = (zip.path, _staging.path);
      final result =
          await Isolate.run(() {
            final staging = Directory(stagingPath);
            if (staging.existsSync()) staging.deleteSync(recursive: true);
            try {
              final imported = GtfsImport.build(
                ZipReader(File(zipPath).readAsBytesSync()),
                staging,
              );
              var bytes = 0;
              for (final file in staging.listSync(recursive: true)) {
                if (file is File) bytes += file.lengthSync();
              }
              return (imported, bytes);
            } on Object {
              if (staging.existsSync()) staging.deleteSync(recursive: true);
              rethrow;
            }
          }).catchError((Object error) {
            throw ServiceException(ServiceFailure.malformedResponse, error);
          }, test: (error) => error is FormatException || error is RangeError);
      final (imported, bytes) = result;
      final info = TransitInfo(
        downloaded: DateTime.now(),
        validFrom: imported.validFrom,
        validUntil: imported.validUntil,
        bytes: bytes,
        stops: imported.stops,
      );
      await File(
        '${_staging.path}/info.json',
      ).writeAsString(jsonEncode(info.toJson()), flush: true);
      if (_directory.existsSync()) await _directory.delete(recursive: true);
      await _staging.rename(_directory.path);
      return info;
    } finally {
      if (zip.existsSync()) await zip.delete();
      if (_staging.existsSync()) await _staging.delete(recursive: true);
    }
  }

  Future<void> _fetch(
    File target, {
    required String userAgent,
    bool Function()? isCancelled,
    void Function(int received, int? total)? onProgress,
  }) async {
    final request = http.Request('GET', url)..headers['User-Agent'] = userAgent;
    final http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(_stallTimeout);
    } on TimeoutException catch (error) {
      throw ServiceException(ServiceFailure.timeout, error);
    } on http.ClientException catch (error) {
      throw ServiceException(ServiceFailure.noConnection, error);
    }
    if (response.statusCode != 200) {
      throw ServiceException(ServiceFailure.unavailable, response.statusCode);
    }
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(_stallTimeout)) {
        if (isCancelled?.call() ?? false) throw const DownloadCancelled();
        received += chunk.length;
        if (received > _maxDownload) {
          throw const ServiceException(ServiceFailure.malformedResponse);
        }
        sink.add(chunk);
        onProgress?.call(received, response.contentLength);
      }
    } on Object catch (error) {
      if (error is DownloadCancelled || error is ServiceException) rethrow;
      if (error is TimeoutException) {
        throw ServiceException(ServiceFailure.timeout, error);
      }
      throw ServiceException(ServiceFailure.noConnection, error);
    } finally {
      await sink.close();
    }
  }

  Future<void> delete() async {
    final transit = Directory('${root.path}/transit');
    if (transit.existsSync()) await transit.delete(recursive: true);
  }

  Future<List<TransitStop>> loadStops() async {
    final json = await _read('stops.json');
    if (json is! List) return const [];
    return [
      for (final (index, entry) in json.indexed)
        if (entry case [
          final String id,
          final String name,
          final num lat,
          final num lon,
          ...,
        ])
          if (GeoPoint.tryCreate(lat, lon) case final point?)
            TransitStop(index: index, id: id, name: name, point: point),
    ];
  }

  /// Route indexes serving each stop, by stop index.
  Future<List<List<int>>> loadStopRoutes() async {
    final json = await _read('stops.json');
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry is List && entry.length > 4 && entry[4] is List)
          (entry[4] as List).whereType<int>().toList()
        else
          const <int>[],
    ];
  }

  Future<List<TransitRoute>> loadRoutes() async {
    final json = await _read('routes.json');
    if (json is! List) return const [];
    return [
      for (final (index, entry) in json.indexed)
        if (entry is List && entry.length >= 3)
          TransitRoute(
            index: index,
            name: '${entry[0]}',
            longName: '${entry[1]}',
            color: entry[2] is int ? entry[2] as int : null,
          ),
    ];
  }

  Future<List<ServiceDays>> loadServices() async {
    final json = await _read('services.json');
    if (json is! List) return const [];
    return [
      for (final entry in json)
        ServiceDays.tryParse(entry) ?? const ServiceDays(),
    ];
  }

  Future<List<RawDeparture>> loadDepartures(int stop) async {
    final json = await _read('stops/$stop.json');
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry case [
          final int seconds,
          final int route,
          final String headsign,
          final int service,
        ])
          (seconds, route, headsign, service),
    ];
  }

  Future<RouteSchedule?> loadRoute(int route) async {
    final json = await _read('routes/$route.json');
    if (json is! Map) return null;
    final shapes = json['shapes'];
    final trips = json['trips'];
    if (shapes is! List || trips is! List) return null;
    return RouteSchedule(
      shapes: [
        for (final shape in shapes)
          if (shape is List)
            [
              for (final p in shape)
                if (p case [final num lat, final num lon])
                  ?GeoPoint.tryCreate(lat, lon),
            ],
      ],
      trips: [
        for (final trip in trips)
          if (trip case [
            final int service,
            final int shape,
            final String headsign,
            final List<Object?> times,
            final List<Object?> distances,
          ])
            if (times.length == distances.length && times.length >= 2)
              RouteTrip(
                service: service,
                shape: shape,
                headsign: headsign,
                times: times.whereType<int>().toList(),
                distances: distances.whereType<int>().toList(),
              ),
      ],
    );
  }

  Future<Object?> _read(String name) async {
    final file = File('${_directory.path}/$name');
    if (!file.existsSync()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
  }
}

/// Null when AMTAB timetables are disabled by configuration.
final transitStoreProvider = Provider<TransitStore?>((ref) {
  const url = AppConfig.amtabGtfsUrl;
  if (url.isEmpty) return null;
  return TransitStore(
    ref.watch(placesDataDirectoryProvider),
    ref.watch(httpClientProvider),
    url: Uri.parse(url),
  );
});
