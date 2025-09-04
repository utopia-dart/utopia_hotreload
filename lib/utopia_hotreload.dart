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
/// See the [README](https://pub.dev/packages/utopia_hotreload) for more examples.
library utopia_hotreload;

// Main public API
export 'src/developer_tools.dart' show DeveloperTools;

// Configuration classes that users might need
export 'src/reload_mode.dart' show ReloadMode;
