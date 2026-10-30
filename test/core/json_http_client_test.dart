import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navia/core/errors/app_failure.dart';
import 'package:navia/core/network/json_http_client.dart';

JsonHttpClient _client(MockClientHandler handler) => JsonHttpClient(
  MockClient(handler),
  userAgent: 'Navia/test',
  timeout: const Duration(milliseconds: 50),
);

Matcher _failsWith(ServiceFailure failure) => throwsA(
  isA<ServiceException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  final uri = Uri.parse('https://example.org/api');

  test('sends an identifying User-Agent and decodes JSON', () async {
    late http.Request sent;
    final client = _client((request) async {
      sent = request;
      return http.Response('{"ok":true}', 200);
    });

    final response = await client.getJson(uri);

    expect(sent.headers['User-Agent'], 'Navia/test');
    expect(response.statusCode, 200);
    expect(response.body, {'ok': true});
  });

  test('maps transport errors to noConnection', () {
    final client = _client((_) => throw http.ClientException('offline'));
    expect(client.getJson(uri), _failsWith(ServiceFailure.noConnection));
  });

  test('maps slow responses to timeout', () {
    final client = _client((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{}', 200);
    });
    expect(client.getJson(uri), _failsWith(ServiceFailure.timeout));
  });

  test('maps server errors and rate limiting', () {
    expect(
      _client((_) async => http.Response('', 503)).getJson(uri),
      _failsWith(ServiceFailure.unavailable),
    );
    expect(
      _client((_) async => http.Response('', 429)).getJson(uri),
      _failsWith(ServiceFailure.rateLimited),
    );
  });

  test('rejects non-JSON and non-object bodies', () {
    expect(
      _client((_) async => http.Response('<html>', 200)).getJson(uri),
      _failsWith(ServiceFailure.malformedResponse),
    );
    expect(
      _client((_) async => http.Response('[1, 2]', 200)).getJson(uri),
      _failsWith(ServiceFailure.malformedResponse),
    );
  });

  test('returns JSON client errors to the caller', () async {
    final response = await _client(
      (_) async => http.Response('{"code":"NoRoute"}', 400),
    ).getJson(uri);
    expect(response.statusCode, 400);
    expect(response.body['code'], 'NoRoute');
  });
}
