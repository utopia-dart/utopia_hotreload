import 'dart:async';
import 'file_pattern_matcher.dart';

/// Configuration for a single service in a multi-service development environment.
///
/// Each service can have its own script, watch paths, and reload behavior
/// while sharing the overall development server infrastructure.
class ServiceConfig {
  /// Unique identifier for this service.
  final String name;

  /// The main function/script for this service.
  final Future<void> Function() script;

  /// Display name for this service (defaults to [name]).
  final String? displayName;

  /// Directory paths to watch for changes specific to this service.
  /// If null, uses the global watch paths from DeveloperTools.
  final List<String>? watchPaths;

  /// File extensions to monitor for changes specific to this service.
  /// If null, uses the global watch extensions from DeveloperTools.
  final List<String>? watchExtensions;

  /// Patterns to ignore when watching files for this service.
  /// If null, uses the global ignore patterns from DeveloperTools.
  final List<String>? ignorePatterns;

  /// Whether this service should auto-start when the development server starts.
  final bool autoStart;

  /// Priority level for reload operations (higher values reload first).
  final int priority;

  /// Specific port for this service's VM service (if applicable).
  final int? vmServicePort;

  /// Environment variables specific to this service.
  final Map<String, String> environment;

  /// Working directory for this service (defaults to current directory).
  final String? workingDirectory;

  /// Whether to enable verbose logging for this specific service.
  final bool? verbose;

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

  /// Creates a new service configuration.
  ///
  /// ## Example
  /// ```dart
  /// final apiService = ServiceConfig(
  ///   name: 'api-server',
  ///   script: runApiServer,
  ///   watchPaths: ['lib/api', 'lib/shared'],
  ///   displayName: 'API Server',
  ///   priority: 10,
  /// );
  /// ```
  const ServiceConfig({
    required this.name,
    required this.script,
    this.displayName,
    this.watchPaths,
    this.watchExtensions,
    this.ignorePatterns,
    this.patternMatcher,
    this.patternPresets = const [],
    this.customPatterns = const [],
    this.autoStart = true,
    this.priority = 0,
    this.vmServicePort,
    this.environment = const {},
    this.workingDirectory,
    this.verbose,
  });

  /// Creates a service configuration with advanced pattern matching using presets.
  ServiceConfig.withPatterns({
    required this.name,
    required this.script,
    this.displayName,
    this.watchPaths,
    List<String> presets = const ['dart-project'],
    List<FilePattern> patterns = const [],
    this.autoStart = true,
    this.priority = 0,
    this.vmServicePort,
    this.environment = const {},
    this.workingDirectory,
    this.verbose,
  })  : watchExtensions = null,
        ignorePatterns = null,
        patternPresets = presets,
        customPatterns = patterns,
        patternMatcher = FilePatternMatcher.custom(
          patterns: patterns,
          presets: presets,
        );

  /// Creates a service configuration using a custom pattern matcher.
  const ServiceConfig.withMatcher({
    required this.name,
    required this.script,
    this.displayName,
    this.watchPaths,
    required this.patternMatcher,
    this.autoStart = true,
    this.priority = 0,
    this.vmServicePort,
    this.environment = const {},
    this.workingDirectory,
    this.verbose,
  })  : watchExtensions = null,
        ignorePatterns = null,
        patternPresets = const [],
        customPatterns = const [];

  /// The effective display name for this service.
  String get effectiveDisplayName => displayName ?? name;

  /// Gets the effective pattern matcher for this service.
  ///
  /// Returns the configured [patternMatcher] if available, otherwise creates
  /// one from [patternPresets] and [customPatterns], or returns null to use
  /// legacy extension-based filtering.
  FilePatternMatcher? get effectivePatternMatcher {
    if (patternMatcher != null) {
      return patternMatcher!;
    }

    if (patternPresets.isNotEmpty || customPatterns.isNotEmpty) {
      return FilePatternMatcher.custom(
        patterns: customPatterns,
        presets: patternPresets,
      );
    }

    // Return null to use legacy extension-based filtering
    return null;
  }

  /// Creates a copy of this service config with updated values.
  ServiceConfig copyWith({
    String? name,
    Future<void> Function()? script,
    String? displayName,
    List<String>? watchPaths,
    List<String>? watchExtensions,
    List<String>? ignorePatterns,
    FilePatternMatcher? patternMatcher,
    List<String>? patternPresets,
    List<FilePattern>? customPatterns,
    bool? autoStart,
    int? priority,
    int? vmServicePort,
    Map<String, String>? environment,
    String? workingDirectory,
    bool? verbose,
  }) {
    return ServiceConfig(
      name: name ?? this.name,
      script: script ?? this.script,
      displayName: displayName ?? this.displayName,
      watchPaths: watchPaths ?? this.watchPaths,
      watchExtensions: watchExtensions ?? this.watchExtensions,
      ignorePatterns: ignorePatterns ?? this.ignorePatterns,
      patternMatcher: patternMatcher ?? this.patternMatcher,
      patternPresets: patternPresets ?? this.patternPresets,
      customPatterns: customPatterns ?? this.customPatterns,
      autoStart: autoStart ?? this.autoStart,
      priority: priority ?? this.priority,
      vmServicePort: vmServicePort ?? this.vmServicePort,
      environment: environment ?? this.environment,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      verbose: verbose ?? this.verbose,
    );
  }

  @override
  String toString() {
    return 'ServiceConfig(name: $name, displayName: $effectiveDisplayName, '
        'autoStart: $autoStart, priority: $priority)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceConfig && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}
