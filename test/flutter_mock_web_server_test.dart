import 'dart:convert';

import 'package:flutter_mock_web_server/flutter_mock_web_server.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('MockWebServer', () {
    late MockWebServer server;

    setUp(() async {
      server = MockWebServer();
      await server.start();
    });

    tearDown(() async {
      await server.shutdown();
    });

    test('should return correct port and url', () {
      expect(server.port, isNotNull);
      expect(server.url, equals('http://localhost:${server.port}'));
    });

    test('should enqueue a response', () async {
      server.enqueue(httpCode: 200, body: '{"name": "John"}');

      var response = await http.get(Uri.parse(server.url));

      expect(response.statusCode, equals(200));
      expect(utf8.decode(response.bodyBytes), equals('{"name": "John"}'));
    });

    test('should return request headers', () async {
      server.enqueue(httpCode: 200, body: '{"name": "John"}');

      await http.get(Uri.parse(server.url), headers: {'user-agent': 'Dart'});

      expect(server.takeRequestHeaders()['user-agent']?.first, equals('Dart'));
    });

    test('should verify request count', () async {
      server.enqueue(httpCode: 200, body: '{"name": "John"}');
      server.enqueue(httpCode: 200, body: '{"name": "Jane"}');

      await http.get(Uri.parse(server.url));
      await http.post(Uri.parse(server.url), body: '{"name": "John"}');

      server.verifyRequestCount(2);
    });

    test('should dispatch request', () async {
      server.enqueue(httpCode: 200, body: '{"name": "John"}');
      var response = await server.dispatchRequest(
        http.Request('GET', Uri.parse(server.url)),
      );

      expect(response.statusCode, equals(200));
      expect(utf8.decode(response.bodyBytes), equals('{"name": "John"}'));
    });

    test('should verify no more requests', () async {
      server.enqueue(httpCode: 200, body: '{"name": "John"}');
      final response =
          await http.get(Uri.parse(server.url)); // wait for response

      server.takeRequest(); // take request

      expect(response.statusCode, equals(200)); // verify response status code
      expect(response.body, equals('{"name": "John"}')); // verify response body

      server.verifyNoMoreRequests(); // verify no more requests
    });
  });
}
