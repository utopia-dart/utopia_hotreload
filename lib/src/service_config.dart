import 'dart:async';

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
    this.autoStart = true,
    this.priority = 0,
    this.vmServicePort,
    this.environment = const {},
    this.workingDirectory,
    this.verbose,
  });

  /// The effective display name for this service.
  String get effectiveDisplayName => displayName ?? name;

  /// Creates a copy of this service config with updated values.
  ServiceConfig copyWith({
    String? name,
    Future<void> Function()? script,
    String? displayName,
    List<String>? watchPaths,
    List<String>? watchExtensions,
    List<String>? ignorePatterns,
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
