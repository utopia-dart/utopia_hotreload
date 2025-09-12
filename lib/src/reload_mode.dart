/// Defines the available reload modes for hot reload functionality.
enum ReloadMode {
  /// True hot reload using Dart VM service that preserves application state.
  hotReload,

  /// Hot restart that terminates and restarts the entire process.
  hotRestart,

  /// Automatic mode that uses hot reload when possible, falls back to restart.
  auto,
}

/// Configuration options for hot reload and restart functionality.
class ReloadConfig {
  /// The reload mode to use.
  final ReloadMode mode;

  /// Directory paths to watch for changes.
  final List<String> watchPaths;

  /// File extensions to monitor for changes.
  final List<String> watchExtensions;

  /// Patterns to ignore when watching files.
  final List<String> ignorePatterns;

  /// Debounce duration to prevent excessive reload triggers.
  final Duration debounceDelay;

  /// Whether to enable verbose logging for debugging.
  final bool verbose;

  /// Fixed VM service port for child process to enable consistent hot reload.
  ///
  /// If null, a random available port is chosen on first start and reused
  /// for subsequent restarts during this session.
  final int? childVmServicePort;

  /// Creates a new reload configuration with the specified options.
  const ReloadConfig({
    this.mode = ReloadMode.auto,
    this.watchPaths = const ['lib'],
    this.watchExtensions = const ['.dart'],
    this.ignorePatterns = const [
      '.git/',
      '.dart_tool/',
      'build/',
      'test/',
      '.packages',
      'pubspec.lock',
      '.vscode/',
      '.idea/',
      '*.log',
      '*.tmp',
    ],
    this.debounceDelay = const Duration(milliseconds: 500),
    this.verbose = false,
    this.childVmServicePort,
  });
}
