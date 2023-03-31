### MockWebServer Plugin for Flutter
A plugin that provides a mock web server to test HTTP requests and responses in Dart.

#### Getting Started
1. Import the package: `import 'package:mock_web_server/mock_web_server.dart';`
2. Create an instance of `MockWebServer`: `var server = MockWebServer();`
3. Start the server: `await server.start();`
4. Enqueue HTTP responses to the response queue using `enqueue()`.
5. Dispatch HTTP requests using `dispatchRequest()` and verify the responses received.

#### Example
```
var server = MockWebServer();
await server.start();

server.enqueue(httpCode: 200, body: '{"name": "John"}');

var response = await http.get(server.url);
expect(response.statusCode, equals(200));
expect(response.body, equals('{"name": "John"}'));

server.verifyRequestCount(1);
server.verifyNoMoreRequests();
await server.shutdown();
