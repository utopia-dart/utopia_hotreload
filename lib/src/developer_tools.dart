import 'dart:async';

import 'reload_mode.dart';
import 'hot_reload_manager.dart';

/// Main interface for hot reload/restart functionality
/// This replaces the old HttpDev class and works like Flutter's hot reload
class DeveloperTools {
  DeveloperTools._();

  /// Start a development server with auto hot reload/restart (like Flutter)
  ///
  /// This automatically tries hot reload first, then falls back to hot restart
  /// if hot reload fails. Just like Flutter's behavior.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   await DeveloperTools.start(
  ///     script: () async {
  ///       final app = Http(ShelfServer(InternetAddress.anyIPv4, 8080));
  ///       app.get('/').inject('response').action((Response response) {
  ///         response.text('Hello with hot reload!');
  ///         return response;
  ///       });
  ///       await app.start();
  ///     },
  ///     watchPaths: ['lib', 'example'],
  ///     watchExtensions: ['.dart'],
  ///   );
  /// }
  /// ```
  ///
  /// During development, use:
  /// - 'r' + Enter: Hot reload (preserves state)
  /// - 'R' + Enter: Hot restart (full restart)
  /// - 'q' + Enter: Quit
  static Future<void> start({
    required Future<void> Function() script,
    List<String> watchPaths = const ['lib'],
    List<String> watchExtensions = const ['.dart'],
    List<String> ignorePatterns = const [
      '.git/',
      '.dart_tool/',
      'build/',
      'pubspec.lock',
    ],
    Duration debounceDelay = const Duration(milliseconds: 500),
    bool verbose = false,
  }) async {
    final config = ReloadConfig(
      mode: ReloadMode.auto, // Always auto mode like Flutter
      watchPaths: watchPaths,
      watchExtensions: watchExtensions,
      ignorePatterns: ignorePatterns,
      debounceDelay: debounceDelay,
      verbose: verbose,
    );

    print('🔥 Hot reload enabled. Press:');
    print('  r + Enter: Hot reload');
    print('  R + Enter: Hot restart');
    print('  q + Enter: Quit');
    print('');

    // Start the auto reload manager that tries hot reload first, then hot restart
    final manager = AutoReloadManager(script: script, config: config);
    await manager.start();
  }
}
