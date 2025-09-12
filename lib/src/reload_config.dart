import 'file_pattern_matcher.dart';

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

  /// Advanced file pattern matcher for sophisticated filtering.
  ///
  /// When provided, this takes precedence over [watchExtensions] and [ignorePatterns].
  /// Supports glob patterns, regex, and predefined presets.
  final FilePatternMatcher? patternMatcher;

  /// Preset patterns to use for file matching.
  ///
  /// Common values: 'dart-project', 'web-project', 'flutter-project', 'test-only', 'config-only'.
  /// When provided, a [FilePatternMatcher] is automatically created from the preset.
  final List<String> patternPresets;

  /// Custom file patterns to use in addition to presets.
  final List<FilePattern> customPatterns;

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
    this.patternMatcher,
    this.patternPresets = const [],
    this.customPatterns = const [],
    this.debounceDelay = const Duration(milliseconds: 500),
    this.verbose = false,
    this.childVmServicePort,
  });

  /// Creates a configuration with advanced pattern matching using presets.
  ReloadConfig.withPatterns({
    this.mode = ReloadMode.auto,
    this.watchPaths = const ['lib'],
    List<String> presets = const ['dart-project'],
    List<FilePattern> patterns = const [],
    this.debounceDelay = const Duration(milliseconds: 500),
    this.verbose = false,
    this.childVmServicePort,
  })  : watchExtensions = const ['.dart'],
        ignorePatterns = const [],
        patternPresets = presets,
        customPatterns = patterns,
        patternMatcher = FilePatternMatcher.custom(
          patterns: patterns,
          presets: presets,
        );

  /// Creates a configuration using a custom pattern matcher.
  const ReloadConfig.withMatcher({
    this.mode = ReloadMode.auto,
    this.watchPaths = const ['lib'],
    required this.patternMatcher,
    this.debounceDelay = const Duration(milliseconds: 500),
    this.verbose = false,
    this.childVmServicePort,
  })  : watchExtensions = const ['.dart'],
        ignorePatterns = const [],
        patternPresets = const [],
        customPatterns = const [];

  /// Gets the effective pattern matcher for this configuration.
  ///
  /// Returns the configured [patternMatcher] if available, otherwise creates
  /// one from [patternPresets] and [customPatterns], or falls back to
  /// a simple extension-based matcher.
  FilePatternMatcher get effectivePatternMatcher {
    if (patternMatcher != null) {
      return patternMatcher!;
    }

    if (patternPresets.isNotEmpty || customPatterns.isNotEmpty) {
      return FilePatternMatcher.custom(
        patterns: customPatterns,
        presets: patternPresets,
      );
    }

    // Fallback: create a simple pattern matcher from extensions and ignore patterns
    final patterns = <FilePattern>[];

    // Add include patterns for extensions
    for (final ext in watchExtensions) {
      final normalizedExt = ext.startsWith('.') ? ext : '.$ext';
      patterns.add(FilePattern.include(
        '**/*$normalizedExt',
        description: 'Include $normalizedExt files',
      ));
    }

    // Add exclude patterns from ignore patterns
    for (final ignore in ignorePatterns) {
      patterns.add(FilePattern.exclude(
        ignore.endsWith('/') ? '$ignore**' : ignore,
        description: 'Ignore $ignore',
        priority: 10, // Higher priority to override includes
      ));
    }

    return FilePatternMatcher(patterns);
  }
}
