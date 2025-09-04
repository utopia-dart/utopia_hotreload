/// Reload modes for hot reload functionality
enum ReloadMode {
  /// True hot reload using Dart VM service (preserves state)
  hotReload,

  /// Hot restart (restarts the process)
  hotRestart,

  /// Automatic mode - uses hot reload when possible, falls back to restart
  auto,
}

/// Configuration for hot reload/restart functionality
class ReloadConfig {
  /// Reload mode to use
  final ReloadMode mode;

  /// Paths to watch for changes
  final List<String> watchPaths;

  /// File extensions to watch
  final List<String> watchExtensions;

  /// Patterns to ignore when watching files
  final List<String> ignorePatterns;

  /// Debounce duration for file changes
  final Duration debounceDelay;

  /// Whether to enable verbose logging
  final bool verbose;

  /// Fixed VM service port for child process (DeveloperTools) to enable
  /// true hot reload without changing the port across hot restarts.
  ///
  /// If null, a random available port is chosen on first start and reused
  /// for subsequent restarts during this session.
  final int? childVmServicePort;

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
