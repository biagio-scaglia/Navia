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

  /// Station registry and prices valid at 8:00, published daily by the
  /// Ministry next to each other at [url].
  static const _files = ['anagrafica_impianti_attivi.csv', 'prezzo_alle_8.csv'];

  /// Downloads today's files from the Ministry, joins them on the device
  /// and installs the result.
  ///
  /// The Ministry's server does not answer GitHub's machines, so the app
  /// downloads the open data directly, only when the user asks.
  Future<FuelDataInfo> download({
    void Function(int received, int? total)? onProgress,
    void Function()? onProcessing,
    bool Function()? isCancelled,
    required String userAgent,
  }) async {
    await _directory.create(recursive: true);
    final parts = <File>[];
    try {
      for (final (index, name) in _files.indexed) {
        final part = File('${_directory.path}/$name.download');
        parts.add(part);
        await _fetch(
          url.resolve(name),
          part,
          userAgent: userAgent,
          isCancelled: isCancelled,
          // Each file is about half of the total.
          onProgress: (bytes, total) => onProgress?.call(
            index * 1000 + (total == null ? 0 : bytes * 1000 ~/ total),
            _files.length * 1000,
          ),
        );
      }
      final (stationsPath, pricesPath, dataPath) = (
        parts[0].path,
        parts[1].path,
        '${_data.path}.download',
      );
      // Joining about 22,000 stations takes a few seconds on a phone.
      onProcessing?.call();
      final extracted = await Isolate.run(
        () => joinMinistryFiles(stationsPath, pricesPath, dataPath),
      );
      if (extracted == null) {
        throw const ServiceException(ServiceFailure.malformedResponse);
      }
      final joined = File(dataPath);
      final bytes = joined.lengthSync();
      if (_data.existsSync()) await _data.delete();
      await joined.rename(_data.path);
      await _info.writeAsString(
        jsonEncode({'extracted': extracted.toIso8601String(), 'bytes': bytes}),
        flush: true,
      );
      return FuelDataInfo(extracted: extracted, bytes: bytes);
    } finally {
      for (final part in parts) {
        if (part.existsSync()) await part.delete();
      }
      final leftover = File('${_data.path}.download');
      if (leftover.existsSync()) await leftover.delete();
    }
  }

  /// Streams [uri] into [target]; returns the bytes received.
  Future<int> _fetch(
    Uri uri,
    File target, {
    required String userAgent,
    bool Function()? isCancelled,
    void Function(int received, int? total)? onProgress,
  }) async {
    final request = http.Request('GET', uri)..headers['User-Agent'] = userAgent;
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
        // Each file is a few MB: anything far larger is wrong.
        if (received > 40 * 1024 * 1024) {
          throw const ServiceException(ServiceFailure.malformedResponse);
        }
        sink.add(chunk);
        onProgress?.call(received, response.contentLength);
      }
    } on Object catch (error) {
      await sink.close();
      if (error is DownloadCancelled || error is ServiceException) rethrow;
      if (error is TimeoutException) {
        throw ServiceException(ServiceFailure.timeout, error);
      }
      throw ServiceException(ServiceFailure.noConnection, error);
    }
    await sink.close();
    return received;
  }

  /// Joins the Ministry's registry and price files into Navia's gzipped
  /// JSON format at [outPath]; returns the extraction day, or null when the
  /// files are not the expected ones.
  ///
  /// Both files are pipe-separated and start with an
  /// "Estrazione del YYYY-MM-DD" line. Implausible prices and coordinates
  /// outside Italy are reporting mistakes and are dropped.
  @visibleForTesting
  static DateTime? joinMinistryFiles(
    String stationsPath,
    String pricesPath,
    String outPath,
  ) {
    List<String> lines(String path) =>
        latin1Safe(File(path).readAsBytesSync()).split(RegExp('\r?\n'));

    final stationLines = lines(stationsPath);
    final priceLines = lines(pricesPath);
    if (stationLines.length < 2 || priceLines.length < 2) return null;
    final extracted = DateTime.tryParse(
      stationLines.first.replaceAll('Estrazione del', '').trim(),
    );
    final stationHeader = stationLines[1].split('|');
    final priceHeader = priceLines[1].split('|');
    final sId = stationHeader.indexOf('idImpianto');
    final sBrand = stationHeader.indexOf('Bandiera');
    final sName = stationHeader.indexOf('Nome Impianto');
    final sAddress = stationHeader.indexOf('Indirizzo');
    final sTown = stationHeader.indexOf('Comune');
    final sLat = stationHeader.indexOf('Latitudine');
    final sLon = stationHeader.indexOf('Longitudine');
    final pId = priceHeader.indexOf('idImpianto');
    final pFuel = priceHeader.indexOf('descCarburante');
    final pPrice = priceHeader.indexOf('prezzo');
    final pSelf = priceHeader.indexOf('isSelf');
    final pTime = priceHeader.indexOf('dtComu');
    if (extracted == null ||
        [sId, sLat, sLon, pId, pFuel, pPrice, pSelf, pTime].contains(-1)) {
      return null;
    }

    final prices = <String, List<List<Object>>>{};
    for (final line in priceLines.skip(2)) {
      final fields = line.split('|');
      if (fields.length < priceHeader.length) continue;
      final value = double.tryParse(fields[pPrice]);
      final reported = _ministryTime(fields[pTime]);
      final fuel = fields[pFuel].trim();
      if (value == null || reported == null || fuel.isEmpty) continue;
      if (value <= 0.3 || value >= 5) continue;
      prices.putIfAbsent(fields[pId], () => []).add([
        fuel,
        (value * 1000).round() / 1000,
        fields[pSelf] == '1',
        reported,
      ]);
    }

    String field(List<String> fields, int index) =>
        index < 0 || index >= fields.length
        ? ''
        : fields[index].trim().replaceAll(RegExp(' +'), ' ');

    final stations = <List<Object>>[];
    for (final line in stationLines.skip(2)) {
      final fields = line.split('|');
      if (fields.length < stationHeader.length) continue;
      final entries = prices[fields[sId]];
      final id = int.tryParse(fields[sId]);
      final lat = double.tryParse(fields[sLat]);
      final lon = double.tryParse(fields[sLon]);
      if (entries == null || id == null || lat == null || lon == null) {
        continue;
      }
      if (lat <= 35 || lat >= 48 || lon <= 6 || lon >= 19) continue;
      stations.add([
        id,
        lat,
        lon,
        field(fields, sBrand),
        field(fields, sName),
        field(fields, sAddress),
        field(fields, sTown),
        entries,
      ]);
    }
    if (stations.isEmpty) return null;

    final json = jsonEncode({
      'version': 1,
      'extracted': extracted.toIso8601String().substring(0, 10),
      'source': 'MIMIT - Osservaprezzi carburanti',
      'license': 'IODL-2.0',
      'stations': stations,
    });
    File(outPath).writeAsBytesSync(gzip.encode(utf8.encode(json)));
    return extracted;
  }

  /// Decodes UTF-8, falling back to Latin-1 for files saved in that
  /// encoding.
  static String latin1Safe(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  /// "23/10/2026 20:00:07" as "2026-10-23T20:00".
  static String? _ministryTime(String value) {
    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})',
    ).firstMatch(value.trim());
    if (match == null) return null;
    return '${match[3]}-${match[2]}-${match[1]}T${match[4]}:${match[5]}';
  }

  Future<void> delete() async {
    if (_directory.existsSync()) await _directory.delete(recursive: true);
  }

  /// All stations of the installed dataset, parsed in the background.
  Future<List<FuelStation>> load() {
    final path = _data.path;
    return Isolate.run(() => _parse(path));
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
