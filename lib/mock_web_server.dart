import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A mock web server that can be used to test HTTP requests and responses in Dart.
class MockWebServer {
  late HttpServer _server;
  final List<HttpHeaders> _requestHeaders = [];
  final List<QueueItem> _responseQueue = [];
  final List<http.Request> _requests = [];
  final StreamController<http.Request> _requestController =
      StreamController.broadcast();
  int _port = -1;

  /// The port on which the server is listening.
  int get port => _port;

  /// The URL of the server.
  String get url => 'http://localhost:$_port';

  /// Starts the server.
  ///
  /// The server will listen on [port] if passed, otherwise it will use a randomly selected port.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start(); // Start the server
  /// ```
  Future<void> start({int? port}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port ?? 0);
    _port = _server.port;
    _server.listen((HttpRequest request) {
      _requestHeaders.add(request.headers);
      _requests.add(http.Request(request.method, Uri.parse(request.uri.path)));

      request.drain().then((_) {
        _requestController.add(http.Request(request.method, request.uri));
        if (_responseQueue.isEmpty) {
          throw StateError('Request received, but no response queued');
        }
        final response = _responseQueue.removeAt(0);
        final httpResponse = request.response;
        httpResponse.statusCode = response.httpCode;
        httpResponse.headers.contentType =
            ContentType.parse(response.contentType);
        httpResponse.headers.set('x-mockwebserver-content-type',
            response.contentType); // Preserved for compatibility
        httpResponse.write(response.body);
        httpResponse.close();
      });
    });
  }

  /// Shuts down the server.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start(); // Start the server
  /// await server.shutdown(); // Stop the server
  /// ```
  Future<void> shutdown() async {
    await _server.close(force: true);
    _responseQueue.clear();
    _requests.clear();
    _requestHeaders.clear();
    _port = -1;
  }

  /// Adds an HTTP response to the response queue.
  ///
  /// [httpCode] is the status code of the HTTP response.
  ///
  /// [body] is the body of the HTTP response.
  ///
  /// [contentType] is the content type of the HTTP response, it defaults to `application/json`.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start();
  /// server.enqueue(httpCode: 200, body: '{"name": "John"}');
  /// ```
  void enqueue(
      {required int httpCode, required String body, String? contentType}) {
    _responseQueue
        .add(QueueItem(httpCode, body, contentType ?? 'application/json'));
  }

  /// Stream of incoming HTTP request.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start();
  ///
  /// server.requestStream.listen((request) {
  ///   print('Request received: ${request.uri}');
  /// });
  /// ``
  Stream<http.Request> get requestStream => _requestController.stream;

  /// Returns the headers of the next HTTP request received by the server.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start();
  ///
  /// var response = await http.get(server.url);
  /// expect(server.takeRequestHeaders()['user-agent'], startsWith('Dart'));
  /// ```
  HttpHeaders takeRequestHeaders() {
    if (_requestHeaders.isEmpty) {
      throw StateError('No request header received');
    }
    return _requestHeaders.removeAt(0);
  }

  /// Returns the next HTTP request received by the server.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start();
  ///
  /// var response = await http.get(server.url);
  /// expect(server.takeRequest().method, 'GET');
  /// expect(server.takeRequest().uri.toString(), equals(server.url));
  /// ```
  http.Request takeRequest() {
    if (_requests.isEmpty) {
      throw StateError('No request received');
    }
    return _requests.removeAt(0);
  }

  /// Verifies that the server has received a certain number of HTTP requests.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = Mock
  /// WebServer();
  /// await server.start();
  ///
  /// var response1 = http.get(server.url);
  /// var response2 = http.post(server.url, body: '{"name": "John"}');
  ///
  /// server.verifyRequestCount(2);
  /// ```
  void verifyRequestCount(int count) {
    if (_requests.length != count) {
      throw StateError(
          'Expected $count requests, but received ${_requests.length}');
    }
  }

  /// Dispatch an HTTP request.
  ///
  /// Returns a Future that completes with an [http.Response] object containing the HTTP response.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start();
  ///
  /// var response = await server.dispatchRequest(http.Request('GET', Uri.parse(server.url)));
  /// expect(response.statusCode, equals(200));
  /// expect(utf8.decode(response.bodyBytes), equals('{"name": "John"}'));
  /// ```
  Future<http.Response> dispatchRequest(http.Request request) async {
    if (_responseQueue.isEmpty) {
      throw StateError('Request dispatched, but no response queued');
    }
    final response = _responseQueue.removeAt(0);
    return http.Response(response.body, response.httpCode,
        headers: {
          'content-type': response.contentType,
          'x-mockwebserver-content-type': response.contentType
        },
        request: request);
  }

  /// Verifies that there are no more incoming HTTP requests.
  ///
  /// Example:
  ///
  /// ```dart
  /// var server = MockWebServer();
  /// await server.start();
  /// http.get(server.url);
  /// server.verifyNoMoreRequests();
  /// ```
  void verifyNoMoreRequests() {
    if (_requests.isNotEmpty) {
      final request = _requests.removeAt(0);
      throw StateError(
          'Request queue not empty. Remaining request: ${request.method} ${request.url}');
    }
  }
}

/// Represents an item in the response queue.
class QueueItem {
  final int httpCode;
  final String body;
  final String contentType;

  QueueItem(this.httpCode, this.body, this.contentType);
}
