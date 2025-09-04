import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'reload_mode.dart';
import 'auto_reload_manager.dart';

/// Main interface for hot reload/restart functionality.
///
/// This replaces the old HttpDev class and works like Flutter's hot reload,
/// providing a seamless development experience with automatic reloading.
///
/// The DeveloperTools class provides a single entry point for starting
/// a development server with hot reload capabilities.
class DeveloperTools {
  DeveloperTools._();

  /// Start a development server with auto hot reload/restart (like Flutter).
  ///
  /// This automatically tries hot reload first, then falls back to hot restart
  /// if hot reload fails. Just like Flutter's behavior.
  ///
  /// **Parameters:**
  /// - [script]: Your application entry point function
  /// - [watchPaths]: Directories to watch for changes (default: `['lib']`)
  /// - [watchExtensions]: File extensions to monitor (default: `['.dart']`)
  /// - [ignorePatterns]: Patterns to ignore when watching files
  /// - [debounceDelay]: Delay before triggering reload (default: 500ms)
  /// - [verbose]: Enable detailed logging (default: false)
  ///
  /// **Example:**
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
  /// **During development, use:**
  /// - `r` + Enter: Hot reload (preserves state)
  /// - `R` + Enter: Hot restart (full restart)
  /// - `q` + Enter: Quit
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
    // Check if VM service is enabled, if not, restart with VM service
    await _ensureVmServiceEnabled();

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

  /// Ensure VM service is enabled for true hot reload
  static Future<void> _ensureVmServiceEnabled() async {
    try {
      // Try to get service info
      final serviceInfo = await developer.Service.getInfo();
      if (serviceInfo.serverUri != null) {
        // VM service is already enabled
        return;
      }
    } catch (e) {
      // Service not available
    }

    // VM service is not enabled, restart with it enabled
    if (!Platform.executableArguments.any((arg) =>
        arg.startsWith('--enable-vm-service') || arg.startsWith('--observe'))) {
      print('🔄 Restarting with VM service enabled for true hot reload...');

      final scriptPath = Platform.script.toFilePath();
      final args = [
        '--enable-vm-service=0', // Use port 0 for automatic port selection
        '--disable-service-auth-codes',
        ...Platform.executableArguments,
        scriptPath,
      ];

      final process = await Process.start(Platform.executable, args);

      // Forward stdout and stderr
      process.stdout.listen((data) => stdout.add(data));
      process.stderr.listen((data) => stderr.add(data));

      final exitCode = await process.exitCode;
      exit(exitCode);
    }
  }
}
