import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  // Flutter-like hot reload experience
  await DeveloperTools.start(
    script: () async {
      print('Server starting... (PID: ${pid})');

      // Your server code here
      final server = await HttpServer.bind('127.0.0.1', 8080);
      print('🚀 Server running on http://127.0.0.1:8080');

      await for (final request in server) {
        request.response
          ..headers.contentType = ContentType.text
          ..write('Hello from hot reload! Time: ${DateTime.now()}')
          ..close();
      }
    },
    watchPaths: ['lib', 'bin'],
    watchExtensions: ['.dart'],
    debounceDelay: Duration(milliseconds: 500),
    ignorePatterns: ['**/.dart_tool/**', '**/build/**'],
  );
}
