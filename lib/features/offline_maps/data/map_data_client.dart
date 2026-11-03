import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../core/network/verified_download.dart';
import '../domain/map_region.dart';

/// Reads the catalog of downloadable maps and downloads them.
///
/// The maps are PMTiles archives published as release assets of the Navia
/// repository on GitHub, built monthly from OpenStreetMap extracts.
class MapDataClient {
  MapDataClient(
    this._http,
    this._json, {
    required this.baseUrl,
    required this.userAgent,
  });

  final http.Client _http;
  final JsonHttpClient _json;
  final String baseUrl;
  final String userAgent;

  Future<List<MapRegion>> catalog() async {
    final response = await _json.getJson(Uri.parse('$baseUrl/manifest.json'));
    if (response.statusCode >= 400) {
      throw ServiceException(ServiceFailure.unavailable, response.statusCode);
    }
    return parseCatalog(response.body);
  }

  static List<MapRegion> parseCatalog(Map<String, dynamic> body) {
    final regions = body['regions'];
    if (body['version'] != 1 || regions is! List) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
    return [for (final entry in regions) ?MapRegion.tryParse(entry)];
  }

  /// Downloads the archive of [region] to [target], checked against the
  /// catalog size and SHA-256.
  Future<void> download(
    MapRegion region,
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

/// The configured map source, or null when offline maps are disabled.
final mapDataClientProvider = Provider<MapDataClient?>((ref) {
  const baseUrl = AppConfig.mapDataUrl;
  if (baseUrl.isEmpty) return null;
  final json = ref.watch(jsonHttpClientProvider);
  return MapDataClient(
    ref.watch(httpClientProvider),
    json,
    baseUrl: baseUrl,
    userAgent: json.userAgent,
  );
});
