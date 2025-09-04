import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  // Flutter-like hot reload experience
  await DeveloperTools.start(
    script: () async {
      print('Server starting... (PID: $pid)');

      // Your server code here - try multiple ports for better compatibility
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

      print('🚀 Server running on http://127.0.0.1:$port');

      await for (final request in server) {
        request.response
          ..headers.contentType = ContentType.text
          ..write('Hello from hot reload! Time: ${DateTime.now()} - UPDATED!')
          ..close();
      }
    },
    watchPaths: ['lib', 'example'],
    watchExtensions: ['.dart'],
    debounceDelay: Duration(milliseconds: 500),
    ignorePatterns: ['**/.dart_tool/**', '**/build/**'],
    verbose: true,
  );
}
