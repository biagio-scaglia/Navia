import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';

/// Thrown when the user cancels a download.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// No progress for this long aborts a download.
const _stallTimeout = Duration(seconds: 30);

/// Downloads [url] to [target], reporting received and total bytes.
///
/// The file is checked against the expected [bytes] and lowercase
/// hexadecimal [sha256]; a mismatch deletes it and throws. [isCancelled] is
/// checked for every chunk.
Future<void> downloadVerified(
  http.Client client,
  Uri url,
  File target, {
  required int bytes,
  required String sha256,
  required String userAgent,
  void Function(int received, int total)? onProgress,
  bool Function()? isCancelled,
}) async {
  final request = http.Request('GET', url)..headers['User-Agent'] = userAgent;
  final http.StreamedResponse response;
  try {
    response = await client.send(request).timeout(_stallTimeout);
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
  final hasher = crypto.sha256.startChunkedConversion(digest);
  var received = 0;
  try {
    await for (final chunk in response.stream.timeout(_stallTimeout)) {
      if (isCancelled?.call() ?? false) throw const DownloadCancelled();
      received += chunk.length;
      if (received > bytes) {
        throw const ServiceException(ServiceFailure.malformedResponse);
      }
      sink.add(chunk);
      hasher.add(chunk);
      onProgress?.call(received, bytes);
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

  if (received != bytes || digest.value.toString() != sha256) {
    await target.delete();
    throw const ServiceException(ServiceFailure.malformedResponse);
  }
}

class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}
