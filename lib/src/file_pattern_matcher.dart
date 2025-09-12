import 'package:path/path.dart' as path;

/// Represents a single file pattern matching rule.
class FilePattern {
  /// The pattern string (glob, regex, or simple string).
  final String pattern;

  /// The type of pattern matching to use.
  final PatternType type;

  /// Whether this is an include (true) or exclude (false) rule.
  final bool include;

  /// Priority for this pattern (higher numbers take precedence).
  final int priority;

  /// Optional description for documentation.
  final String? description;

  const FilePattern({
    required this.pattern,
    this.type = PatternType.glob,
    this.include = true,
    this.priority = 0,
    this.description,
  });

  /// Creates an include pattern.
  const FilePattern.include(
    String pattern, {
    PatternType type = PatternType.glob,
    int priority = 0,
    String? description,
  }) : this(
          pattern: pattern,
          type: type,
          include: true,
          priority: priority,
          description: description,
        );

  /// Creates an exclude pattern.
  const FilePattern.exclude(
    String pattern, {
    PatternType type = PatternType.glob,
    int priority = 10, // Exclude patterns get higher default priority
    String? description,
  }) : this(
          pattern: pattern,
          type: type,
          include: false,
          priority: priority,
          description: description,
        );

  @override
  String toString() {
    final prefix = include ? 'include' : 'exclude';
    final typeStr = type.name;
    return 'FilePattern.$prefix("$pattern", type: $typeStr, priority: $priority)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilePattern &&
          runtimeType == other.runtimeType &&
          pattern == other.pattern &&
          type == other.type &&
          include == other.include &&
          priority == other.priority;

  @override
  int get hashCode =>
      pattern.hashCode ^ type.hashCode ^ include.hashCode ^ priority.hashCode;
}

/// Types of pattern matching supported.
enum PatternType {
  /// Glob patterns like `**/*.dart`, `lib/**/*.{dart,yaml}`.
  glob,

  /// Regular expression patterns.
  regex,

  /// Simple string matching (contains, starts with, ends with).
  simple,

  /// File extension matching.
  extension,
}

/// Predefined pattern presets for common use cases.
class PatternPresets {
  PatternPresets._();

  /// Standard Dart project patterns.
  static const List<FilePattern> dartProject = [
    FilePattern.include('**/*.dart', description: 'All Dart files'),
    FilePattern.include('**/pubspec.yaml', description: 'Pubspec files'),
    FilePattern.include('**/analysis_options.yaml',
        description: 'Analysis options'),
    FilePattern.exclude('.dart_tool/**', description: 'Build artifacts'),
    FilePattern.exclude('build/**', description: 'Build output'),
    FilePattern.exclude('.git/**', description: 'Git files'),
    FilePattern.exclude('**/.packages', description: 'Legacy packages file'),
    FilePattern.exclude('**/pubspec.lock',
        priority: 10, description: 'Lock files'),
  ];

  /// Web development patterns.
  static const List<FilePattern> webProject = [
    FilePattern.include('**/*.dart', description: 'Dart files'),
    FilePattern.include('**/*.html', description: 'HTML files'),
    FilePattern.include('**/*.css', description: 'CSS files'),
    FilePattern.include('**/*.js', description: 'JavaScript files'),
    FilePattern.include('**/*.json', description: 'JSON files'),
    FilePattern.include('**/*.yaml', description: 'YAML files'),
    FilePattern.include('**/*.yml', description: 'YAML files'),
    FilePattern.exclude('node_modules/**', description: 'Node modules'),
    FilePattern.exclude('.dart_tool/**', description: 'Build artifacts'),
    FilePattern.exclude('build/**', description: 'Build output'),
    FilePattern.exclude('.git/**', description: 'Git files'),
  ];

  /// Flutter project patterns.
  static const List<FilePattern> flutterProject = [
    ...dartProject,
    FilePattern.include('**/*.g.dart',
        priority: 5, description: 'Generated Dart files'),
    FilePattern.include('android/**/*.gradle',
        description: 'Android Gradle files'),
    FilePattern.include('android/**/AndroidManifest.xml',
        description: 'Android manifest'),
    FilePattern.include('ios/**/*.plist', description: 'iOS plist files'),
    FilePattern.include('lib/**/*.dart',
        priority: 10, description: 'Main source files'),
    FilePattern.include('test/**/*_test.dart', description: 'Test files'),
    FilePattern.exclude('android/**/build/**', description: 'Android build'),
    FilePattern.exclude('ios/**/build/**', description: 'iOS build'),
    FilePattern.exclude('**/*.g.dart',
        priority: -5, description: 'Exclude generated (unless overridden)'),
  ];

  /// Test-only patterns.
  static const List<FilePattern> testOnly = [
    FilePattern.include('test/**/*_test.dart', description: 'Test files'),
    FilePattern.include('test/**/test_*.dart',
        description: 'Test files (prefix)'),
    FilePattern.include('**/*_test.dart', description: 'All test files'),
    FilePattern.exclude('test/**/*',
        priority: -10, description: 'Exclude non-test files in test/'),
  ];

  /// Configuration files only.
  static const List<FilePattern> configOnly = [
    FilePattern.include('**/pubspec.yaml', description: 'Pubspec files'),
    FilePattern.include('**/analysis_options.yaml',
        description: 'Analysis options'),
    FilePattern.include('**/.gitignore', description: 'Git ignore files'),
    FilePattern.include('**/dart_tool/package_config.json',
        description: 'Package config'),
    FilePattern.include('**/*.env', description: 'Environment files'),
    FilePattern.include('**/*.config.{dart,json,yaml,yml}',
        description: 'Config files'),
  ];

  /// Get patterns by name.
  static List<FilePattern> getByName(String name) {
    switch (name.toLowerCase()) {
      case 'dart':
      case 'dart-project':
        return dartProject;
      case 'web':
      case 'web-project':
        return webProject;
      case 'flutter':
      case 'flutter-project':
        return flutterProject;
      case 'test':
      case 'test-only':
        return testOnly;
      case 'config':
      case 'config-only':
        return configOnly;
      default:
        throw ArgumentError('Unknown pattern preset: $name');
    }
  }

  /// Get all available preset names.
  static List<String> get availablePresets => [
        'dart-project',
        'web-project',
        'flutter-project',
        'test-only',
        'config-only',
      ];
}

/// Advanced file pattern matcher with support for multiple pattern types.
class FilePatternMatcher {
  /// All patterns sorted by priority (highest first).
  final List<FilePattern> _patterns;

  /// Compiled regex patterns for performance.
  final Map<String, RegExp> _regexCache = {};

  /// Creates a pattern matcher with the given patterns.
  FilePatternMatcher(List<FilePattern> patterns)
      : _patterns = List.from(patterns)
          ..sort((a, b) => b.priority.compareTo(a.priority));

  /// Creates a matcher from a preset.
  factory FilePatternMatcher.fromPreset(String presetName) {
    return FilePatternMatcher(PatternPresets.getByName(presetName));
  }

  /// Creates a matcher combining multiple presets.
  factory FilePatternMatcher.fromPresets(List<String> presetNames) {
    final allPatterns = <FilePattern>[];
    for (final name in presetNames) {
      allPatterns.addAll(PatternPresets.getByName(name));
    }
    return FilePatternMatcher(allPatterns);
  }

  /// Creates a matcher with custom patterns plus optional presets.
  factory FilePatternMatcher.custom({
    List<FilePattern> patterns = const [],
    List<String> presets = const [],
  }) {
    final allPatterns = <FilePattern>[...patterns];
    for (final preset in presets) {
      allPatterns.addAll(PatternPresets.getByName(preset));
    }
    return FilePatternMatcher(allPatterns);
  }

  /// Tests if a file path matches the configured patterns.
  ///
  /// Returns true if the file should be included, false if excluded.
  /// Patterns are evaluated in priority order (highest first).
  bool matches(String filePath) {
    // Normalize the path for consistent matching
    final normalizedPath = path.normalize(filePath).replaceAll(r'\', '/');

    // Apply patterns in priority order
    for (final pattern in _patterns) {
      if (_matchesPattern(normalizedPath, pattern)) {
        return pattern.include;
      }
    }

    // Default to exclude if no patterns match
    return false;
  }

  /// Tests if a file path matches a specific pattern.
  bool _matchesPattern(String filePath, FilePattern pattern) {
    switch (pattern.type) {
      case PatternType.glob:
        return _matchesGlob(filePath, pattern.pattern);

      case PatternType.regex:
        return _matchesRegex(filePath, pattern.pattern);

      case PatternType.simple:
        return _matchesSimple(filePath, pattern.pattern);

      case PatternType.extension:
        return _matchesExtension(filePath, pattern.pattern);
    }
  }

  /// Matches against glob patterns.
  bool _matchesGlob(String filePath, String globPattern) {
    // Convert glob to regex and cache it
    final cacheKey = 'glob:$globPattern';
    final regex =
        _regexCache.putIfAbsent(cacheKey, () => _globToRegex(globPattern));
    return regex.hasMatch(filePath);
  }

  /// Matches against regex patterns.
  bool _matchesRegex(String filePath, String regexPattern) {
    final cacheKey = 'regex:$regexPattern';
    final regex = _regexCache.putIfAbsent(cacheKey, () => RegExp(regexPattern));
    return regex.hasMatch(filePath);
  }

  /// Matches against simple string patterns.
  bool _matchesSimple(String filePath, String simplePattern) {
    return filePath.contains(simplePattern);
  }

  /// Matches against file extensions.
  bool _matchesExtension(String filePath, String extension) {
    final normalizedExt = extension.startsWith('.') ? extension : '.$extension';
    return filePath.endsWith(normalizedExt);
  }

  /// Converts a glob pattern to a regular expression.
  RegExp _globToRegex(String glob) {
    var pattern = glob;

    // Handle brace expansion first before any escaping: {dart,yaml} -> (dart|yaml)
    pattern = pattern.replaceAllMapped(
      RegExp(r'\{([^}]+)\}'),
      (match) {
        final options = match.group(1)!.split(',');
        return '(${options.join('|')})';
      },
    );

    // Use placeholders for glob patterns to avoid conflicts during escaping
    pattern = pattern.replaceAll('**/', '___GLOBSTAR_SLASH___');
    pattern = pattern.replaceAll('**', '___GLOBSTAR___');
    pattern = pattern.replaceAll('*', '___STAR___');
    pattern = pattern.replaceAll('?', '___QUESTION___');

    // Escape regex special characters that could be in file paths
    pattern = pattern.replaceAllMapped(
      RegExp(
          r'[.+^$\\]'), // Don't escape () or | as they might be from brace expansion
      (match) => '\\${match.group(0)}',
    );

    // Now replace placeholders with actual regex patterns
    pattern = pattern.replaceAll('___GLOBSTAR_SLASH___', '(?:.*/)?');
    pattern = pattern.replaceAll('___GLOBSTAR___', '.*');
    pattern = pattern.replaceAll('___STAR___', r'[^/]*');
    pattern = pattern.replaceAll('___QUESTION___', r'[^/]');

    // Anchor the pattern
    pattern = '^$pattern\$';

    return RegExp(pattern);
  }

  /// Returns a list of matched patterns for debugging.
  List<FilePattern> getMatchingPatterns(String filePath) {
    final normalizedPath = path.normalize(filePath).replaceAll(r'\', '/');
    final matching = <FilePattern>[];

    for (final pattern in _patterns) {
      if (_matchesPattern(normalizedPath, pattern)) {
        matching.add(pattern);
      }
    }

    return matching;
  }

  /// Returns all patterns sorted by priority.
  List<FilePattern> get patterns => List.unmodifiable(_patterns);

  /// Returns the number of patterns.
  int get patternCount => _patterns.length;

  /// Debug method to see the generated regex for a glob pattern.
  String debugGlobRegex(String globPattern) {
    return _globToRegex(globPattern).pattern;
  }

  @override
  String toString() {
    return 'FilePatternMatcher(${_patterns.length} patterns)';
  }
}
