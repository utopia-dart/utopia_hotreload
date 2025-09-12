/// 🔥 Hot reload and hot restart functionality for Dart applications
///
/// This library provides Flutter-like hot reload capabilities for any Dart application,
/// allowing developers to see changes instantly during development without losing application state.
///
/// ## Features
///
/// - **True Hot Reload**: Uses Dart VM service to reload code while preserving state
/// - **Hot Restart**: Full process restart when hot reload isn't possible
/// - **Auto Mode**: Intelligently tries hot reload first, falls back to restart
/// - **File Watching**: Monitors file changes with configurable paths and extensions
/// - **Advanced Pattern Matching**: Glob patterns, regex, and predefined presets
/// - **Multi-Service Support**: Run multiple services simultaneously with coordinated reload
/// - **Flutter-like Commands**: 'r' for reload, 'R' for restart, 'q' to quit
///
/// ## Quick Start
///
/// ```dart
/// import 'package:utopia_hotreload/utopia_hotreload.dart';
///
/// void main() async {
///   await DeveloperTools.start(
///     script: () async {
///       // Your application code here
///       print('Hello from hot reload!');
///     },
///   );
/// }
/// ```
///
/// ## Advanced Pattern Matching
///
/// ```dart
/// await DeveloperTools.start(
///   script: runMyApp,
///   watchPaths: ['lib', 'web'],
///   patternPresets: ['dart-project', 'web-project'],
///   customPatterns: [
///     FilePattern.include('**/*.env'),
///     FilePattern.exclude('lib/generated/**'),
///   ],
/// );
/// ```
///
/// ## Multi-Service Development
///
/// ```dart
/// await DeveloperTools.startMultiple([
///   ServiceConfig(name: 'api', script: runApiServer),
///   ServiceConfig(name: 'web', script: runWebServer),
/// ]);
/// ```
///
/// See the [README](https://pub.dev/packages/utopia_hotreload) for more examples.
library utopia_hotreload;

// Main public API
export 'src/developer_tools.dart' show DeveloperTools;

// Configuration classes that users might need
export 'src/reload_mode.dart' show ReloadMode;

// Multi-service support
export 'src/service_config.dart' show ServiceConfig;

// Advanced pattern matching
export 'src/file_pattern_matcher.dart'
    show FilePatternMatcher, FilePattern, PatternType, PatternPresets;

// Input handling utilities
export 'src/keyboard_input_handler.dart' show KeyboardInputHandler;
