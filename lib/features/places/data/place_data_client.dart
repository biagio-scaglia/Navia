import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../domain/place_region.dart';

/// Thrown when the user cancels a download.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Reads the catalog of place datasets and downloads them.
///
/// The datasets are static files published as release assets of the Navia
/// repository on GitHub, built monthly from OpenStreetMap extracts.
class PlaceDataClient {
  PlaceDataClient(
    this._http,
    this._json, {
    required this.baseUrl,
    required this.userAgent,
  });

  final http.Client _http;
  final JsonHttpClient _json;
  final String baseUrl;
  final String userAgent;

  /// No progress for this long aborts the download.
  static const _stallTimeout = Duration(seconds: 30);

  Future<List<PlaceRegion>> catalog() async {
    final response = await _json.getJson(Uri.parse('$baseUrl/manifest.json'));
    if (response.statusCode >= 400) {
      throw ServiceException(ServiceFailure.unavailable, response.statusCode);
    }
    return parseCatalog(response.body);
  }

  static List<PlaceRegion> parseCatalog(Map<String, dynamic> body) {
    final regions = body['regions'];
    if (body['version'] != 1 || regions is! List) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
    return [for (final entry in regions) ?PlaceRegion.tryParse(entry)];
  }

  /// Downloads [region] to [target], reporting received and total bytes.
  ///
  /// The file is checked against the catalog size and SHA-256; a mismatch
  /// deletes it and throws. [isCancelled] is checked for every chunk.
  Future<void> download(
    PlaceRegion region,
    File target, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final request = http.Request('GET', Uri.parse('$baseUrl/${region.file}'))
      ..headers['User-Agent'] = userAgent;
    final http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(_stallTimeout);
    } on TimeoutException catch (error) {
      throw ServiceException(ServiceFailure.timeout, error);
    } on http.ClientException catch (error) {
      throw ServiceException(ServiceFailure.noConnection, error);
    }
    if (response.statusCode != 200) {
      throw ServiceException(
        response.statusCode == 429
            ? ServiceFailure.rateLimited
            : ServiceFailure.unavailable,
        'HTTP ${response.statusCode}',
      );
    }

    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(_stallTimeout)) {
        if (isCancelled?.call() ?? false) throw const DownloadCancelled();
        received += chunk.length;
        if (received > region.bytes) {
          throw const ServiceException(ServiceFailure.malformedResponse);
        }
        sink.add(chunk);
        hasher.add(chunk);
        onProgress?.call(received, region.bytes);
      }
      hasher.close();
      await sink.close();
    } on Object catch (error) {
      await sink.close();
      if (target.existsSync()) await target.delete();
      if (error is DownloadCancelled || error is ServiceException) rethrow;
      if (error is TimeoutException) {
        throw ServiceException(ServiceFailure.timeout, error);
      }
      throw ServiceException(ServiceFailure.noConnection, error);
    }

    if (received != region.bytes || digest.value.toString() != region.sha256) {
      await target.delete();
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// The configured dataset source, or null when offline data is disabled.
final placeDataClientProvider = Provider<PlaceDataClient?>((ref) {
  const baseUrl = AppConfig.placesDataUrl;
  if (baseUrl.isEmpty) return null;
  final json = ref.watch(jsonHttpClientProvider);
  return PlaceDataClient(
    ref.watch(httpClientProvider),
    json,
    baseUrl: baseUrl,
    userAgent: json.userAgent,
  );
});
