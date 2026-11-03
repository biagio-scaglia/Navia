import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../core/network/verified_download.dart';
import '../domain/place_region.dart';

export '../../../core/network/verified_download.dart' show DownloadCancelled;

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
  }) => downloadVerified(
    _http,
    Uri.parse('$baseUrl/${region.file}'),
    target,
    bytes: region.bytes,
    sha256: region.sha256,
    userAgent: userAgent,
    onProgress: onProgress,
    isCancelled: isCancelled,
  );
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
