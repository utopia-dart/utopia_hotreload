import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

// Example of using utopia_hotreload with an HTTP server
void main() async {
  await DeveloperTools.start(
    script: () async {
      print('🚀 Example server with hot reload functionality');
      print('✨ Try changing this message and save the file!');
      print('');

      // Simple HTTP server example with robust port handling
      late HttpServer server;
      int port = 8080;

      try {
        // Try multiple ports starting from 8080
        for (port = 8080; port <= 8090; port++) {
          try {
            server = await HttpServer.bind('127.0.0.1', port);
            break;
          } catch (e) {
            if (port == 8090) rethrow;
            continue;
          }
        }
      } catch (e) {
        // If all ports fail, use port 0 for automatic assignment
        server = await HttpServer.bind('127.0.0.1', 0);
        port = server.port;
      }

      print('🌐 Server running on http://127.0.0.1:$port');
      print('');

      await for (final request in server) {
        final response = request.response;

        // Handle different routes
        switch (request.uri.path) {
          case '/':
            response
              ..headers.contentType = ContentType.html
              ..write('''
<!DOCTYPE html>
<html>
<head>
    <title>Hot Reload Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        .highlight { color: #e74c3c; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 Hot Reload Demo</h1>
        <p>Current time: <span class="highlight">${DateTime.now()}</span></p>
        <p>Try editing this file and saving it - the server will automatically reload!</p>
        <p>Commands:</p>
        <ul>
            <li><code>r + Enter</code>: Hot reload (preserves state)</li>
            <li><code>R + Enter</code>: Hot restart (full restart)</li>
            <li><code>q + Enter</code>: Quit</li>
        </ul>
    </div>
</body>
</html>
              ''');
            break;

          case '/api/time':
            response
              ..headers.contentType = ContentType.json
              ..write('{"time": "${DateTime.now().toIso8601String()}"}');
            break;

          default:
            response
              ..statusCode = 404
              ..headers.contentType = ContentType.text
              ..write('404 - Not Found');
        }

        await response.close();
      }
    },
    watchPaths: ['lib', 'example'],
    watchExtensions: ['.dart'],
  );
}
