import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

/// Example showing simple usage with pattern matching
void main() async {
  // Example 1: Using pattern presets (recommended)
  await startWithPresets();

  // Example 2: Using custom patterns (advanced)
  // await startWithCustomPatterns();

  // Example 3: Traditional approach (still supported)
  // await startTraditional();
}

/// Example using pattern presets for common project types
Future<void> startWithPresets() async {
  await DeveloperTools.start(
    script: runMyApp,
    watchPaths: ['lib', 'example'],

    // Use predefined patterns for Dart projects
    // Available presets: 'dart-project', 'web-project', 'flutter-project', 'test-only', 'config-only'
    patternPresets: ['dart-project'],

    // Optionally add custom patterns on top of presets
    customPatterns: [
      FilePattern.include('**/*.env', description: 'Environment files'),
      FilePattern.exclude('lib/generated/**', description: 'Generated code'),
    ],

    verbose: true,
  );
}

/// Example using fully custom patterns
Future<void> startWithCustomPatterns() async {
  await DeveloperTools.start(
    script: runMyApp,
    watchPaths: ['lib', 'example'],

    // Define completely custom pattern matching
    customPatterns: [
      // Include patterns
      FilePattern.include('**/*.dart', description: 'All Dart files'),
      FilePattern.include('**/pubspec.yaml', description: 'Pubspec files'),
      FilePattern.include('**/*.env', description: 'Environment files'),

      // Exclude patterns (higher priority)
      FilePattern.exclude('.dart_tool/**',
          priority: 10, description: 'Build artifacts'),
      FilePattern.exclude('build/**',
          priority: 10, description: 'Build output'),
      FilePattern.exclude('.git/**', priority: 10, description: 'Git files'),
    ],

    verbose: true,
  );
}

/// Example using traditional extension-based approach
Future<void> startTraditional() async {
  await DeveloperTools.start(
    script: runMyApp,
    watchPaths: ['lib', 'example'],

    // Simple extension and ignore pattern approach
    watchExtensions: ['.dart', '.yaml'],
    ignorePatterns: ['.git/', 'build/', '.dart_tool/'],

    verbose: true,
  );
}

Future<void> runMyApp() async {
  final server = await HttpServer.bind('localhost', 8080);
  print('🚀 Server running on http://localhost:8080');

  await for (final request in server) {
    final message = getMessage();
    request.response
      ..headers.contentType = ContentType.html
      ..write('''
        <!DOCTYPE html>
        <html>
        <body>
          <h1>$message</h1>
          <p>Hot reload is working! Try changing the getMessage() function.</p>
          <p>Time: ${DateTime.now()}</p>
        </body>
        </html>
      ''')
      ..close();
  }
}

String getMessage() {
  return 'Hello from hot reload!';
}
