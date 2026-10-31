import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../domain/fuel.dart';
import '../domain/poi.dart';
import 'offline_places_store.dart';
import 'place_data_client.dart';

/// The downloaded fuel price dataset: when it was extracted and its size.
@immutable
class FuelDataInfo {
  const FuelDataInfo({required this.extracted, required this.bytes});

  /// Day of the Ministry's extraction.
  final DateTime extracted;
  final int bytes;
}

/// Downloads and stores the daily fuel prices (MIMIT open data, published
/// by the Navia repository) in private app storage.
class FuelPricesStore {
  FuelPricesStore(this.root, this._http, {required this.url});

  final Directory root;
  final http.Client _http;
  final Uri url;

  /// No progress for this long aborts the download.
  static const _stallTimeout = Duration(seconds: 30);

  Directory get _directory => Directory('${root.path}/fuel');
  File get _data => File('${_directory.path}/fuel-prices.json.gz');
  File get _info => File('${_directory.path}/info.json');

  FuelDataInfo? info() {
    if (!_info.existsSync() || !_data.existsSync()) return null;
    try {
      final json = jsonDecode(_info.readAsStringSync());
      if (json is! Map) return null;
      final extracted = DateTime.tryParse('${json['extracted']}');
      final bytes = json['bytes'];
      if (extracted == null || bytes is! int) return null;
      return FuelDataInfo(extracted: extracted, bytes: bytes);
    } on FormatException {
      return null;
    }
  }

  /// Downloads the current dataset, checks that it parses, and installs it.
  Future<FuelDataInfo> download({
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    required String userAgent,
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

    await _directory.create(recursive: true);
    final temporary = File('${_data.path}.download');
    final sink = temporary.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(_stallTimeout)) {
        if (isCancelled?.call() ?? false) throw const DownloadCancelled();
        received += chunk.length;
        // The national file is about 1.5 MB: anything far larger is wrong.
        if (received > 30 * 1024 * 1024) {
          throw const ServiceException(ServiceFailure.malformedResponse);
        }
        sink.add(chunk);
        onProgress?.call(received, response.contentLength);
      }
      await sink.close();
    } on Object catch (error) {
      await sink.close();
      if (temporary.existsSync()) await temporary.delete();
      if (error is DownloadCancelled || error is ServiceException) rethrow;
      throw ServiceException(ServiceFailure.noConnection, error);
    }

    final path = temporary.path;
    final extracted = await Isolate.run(() => _validate(path));
    if (extracted == null) {
      await temporary.delete();
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
    await temporary.rename(_data.path);
    final info = FuelDataInfo(extracted: extracted, bytes: received);
    await _info.writeAsString(
      jsonEncode({'extracted': extracted.toIso8601String(), 'bytes': received}),
      flush: true,
    );
    return info;
  }

  Future<void> delete() async {
    if (_directory.existsSync()) await _directory.delete(recursive: true);
  }

  /// All stations of the installed dataset, parsed in the background.
  Future<List<FuelStation>> load() {
    final path = _data.path;
    return Isolate.run(() => _parse(path));
  }

  static DateTime? _validate(String path) {
    try {
      final json = jsonDecode(
        utf8.decode(gzip.decode(File(path).readAsBytesSync())),
      );
      if (json is! Map || json['version'] != 1 || json['stations'] is! List) {
        return null;
      }
      return DateTime.tryParse('${json['extracted']}');
    } on FormatException {
      return null;
    }
  }

  static List<FuelStation> _parse(String path) {
    final json = jsonDecode(
      utf8.decode(gzip.decode(File(path).readAsBytesSync())),
    );
    final stations = json is Map ? json['stations'] : null;
    if (stations is! List) return const [];
    return [for (final entry in stations) ?FuelStation.tryParse(entry)];
  }
}

/// Attaches Ministry fuel prices to OpenStreetMap fuel stations.
abstract final class FuelPriceMatcher {
  /// Registry coordinates are often rounded or set at the address, so a
  /// station matches within this distance.
  static const maxDistanceMeters = 80.0;

  /// Returns [places] with [Poi.fuel] set to the nearest registry station
  /// within [maxDistanceMeters], if any.
  static List<Poi> annotate(List<Poi> places, List<FuelStation> stations) {
    if (places.isEmpty || stations.isEmpty) return places;
    const margin = 0.002;
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final place in places) {
      final p = place.point;
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    final nearby = [
      for (final station in stations)
        if (station.point.latitude >= south - margin &&
            station.point.latitude <= north + margin &&
            station.point.longitude >= west - margin &&
            station.point.longitude <= east + margin)
          station,
    ];
    return [
      for (final place in places) place.withFuel(_nearest(place, nearby)),
    ];
  }

  static FuelStation? _nearest(Poi place, List<FuelStation> stations) {
    FuelStation? best;
    var bestDistance = maxDistanceMeters;
    for (final station in stations) {
      final distance = place.point.distanceTo(station.point);
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = station;
      }
    }
    return best;
  }
}

final fuelPricesStoreProvider = Provider<FuelPricesStore?>((ref) {
  const url = AppConfig.fuelDataUrl;
  if (url.isEmpty) return null;
  return FuelPricesStore(
    ref.watch(placesDataDirectoryProvider),
    ref.watch(httpClientProvider),
    url: Uri.parse(url),
  );
});
