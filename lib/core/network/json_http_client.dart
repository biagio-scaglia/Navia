import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/config/app_config.dart';
import '../../shared/providers/package_info_provider.dart';
import '../errors/app_failure.dart';

/// Minimal JSON-over-HTTP client for public OpenStreetMap services.
///
/// Every request carries an identifying User-Agent, as required by the usage
/// policies of the services Navia talks to. Transport and parsing errors are
/// translated into [ServiceException]s.
class JsonHttpClient {
  JsonHttpClient(
    this._client, {
    required this.userAgent,
    this.timeout = const Duration(seconds: 12),
  });

  final http.Client _client;
  final String userAgent;
  final Duration timeout;

  /// Performs a GET request and decodes the JSON object it returns.
  ///
  /// Server errors, rate limiting and non-JSON bodies throw. Other client
  /// errors (4xx) with a JSON body are returned with their status code,
  /// because services such as OSRM explain "no route" errors in the body.
  Future<({int statusCode, Map<String, dynamic> body})> getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw ServiceException(ServiceFailure.timeout, error);
    } on http.ClientException catch (error) {
      // dart:io socket and DNS failures surface as ClientException.
      throw ServiceException(ServiceFailure.noConnection, error);
    }

    final status = response.statusCode;
    if (status == 429) {
      throw const ServiceException(ServiceFailure.rateLimited);
    }
    if (status >= 500) {
      throw ServiceException(ServiceFailure.unavailable, 'HTTP $status');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw ServiceException(
        status >= 400
            ? ServiceFailure.invalidRequest
            : ServiceFailure.malformedResponse,
        error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ServiceException(ServiceFailure.malformedResponse);
    }
    return (statusCode: status, body: decoded);
  }
}

/// Shared HTTP connection pool, closed with the provider container.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final jsonHttpClientProvider = Provider<JsonHttpClient>((ref) {
  final version = ref.watch(packageInfoProvider).version;
  return JsonHttpClient(
    ref.watch(httpClientProvider),
    userAgent: '${AppConfig.appName}/$version (+${AppConfig.sourceCodeUrl})',
  );
});

/// Logs a service error for developers without exposing it to users.
void logServiceError(String service, Object error) {
  debugPrint('[$service] $error');
}
