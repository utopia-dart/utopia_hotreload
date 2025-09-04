# Utopia Hot Reload

Advanced hot reload and hot restart functionality for Dart applications with true VM-based hot reload capabilities, similar to Flutter's development experience.

[![Pub Version](https://img.shields.io/pub/v/utopia_hotreload)](https://pub.dev/packages/utopia_hotreload)
[![Dart SDK Version](https://img.shields.io/badge/dart-%3E%3D2.17.0-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **🔥 True Hot Reload**: Uses Dart VM service to reload code while preserving application state (like Flutter)
- **🔄 Hot Restart**: Full process restart when hot reload isn't possible
- **🚀 Auto Mode**: Intelligently tries hot reload first, falls back to restart
- **⌨️ Flutter-like Commands**: 'r' for hot reload, 'R' for hot restart, 'q' to quit
- **📁 File Watching**: Configurable paths and extensions with debouncing
- **🎯 Smart Fallback**: Graceful error handling with automatic mode switching

## Installation

```yaml
dev_dependencies:
  utopia_hotreload: ^1.0.0
```

## Quick Start

```dart
import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: () async {
      // Your application code here
      final server = await HttpServer.bind('127.0.0.1', 8080);
      print('🚀 Server running on http://127.0.0.1:8080');
      
      await for (final request in server) {
        request.response
          ..write('Hello from hot reload! Time: ${DateTime.now()}')
          ..close();
      }
    },
    watchPaths: ['lib', 'bin'],
    watchExtensions: ['.dart'],
  );
}
```

## Usage

### Basic Usage

The API is designed to be simple and Flutter-like:

```dart
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: () async {
      // Your application code here
    },
  );
}
```

### With Utopia HTTP

```dart
import 'dart:io';
import 'package:utopia_http/utopia_http.dart';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: () async {
      final app = Http(ShelfServer(InternetAddress.anyIPv4, 8080));
      
      app.get('/').inject('response').action((Response response) {
        response.text('Hello with hot reload! 🔥');
        return response;
      });
      
      await app.start();
    },
    watchPaths: ['lib', 'example'],
    watchExtensions: ['.dart'],
  );
}
```

### Advanced Configuration

```dart
await DeveloperTools.start(
  script: () async {
    // Your server code
  },
  watchPaths: ['lib', 'bin', 'web'],
  watchExtensions: ['.dart', '.yaml'],
  ignorePatterns: ['**/.dart_tool/**', '**/build/**'],
  debounceDelay: Duration(milliseconds: 300),
  verbose: true,
);
```

## Flutter-like Development Experience

When you run your application, you'll see:

```
🔥 Hot reload enabled. Press:
  r + Enter: Hot reload
  R + Enter: Hot restart  
  q + Enter: Quit

🚀 Starting application with auto hot reload...
📁 Watching paths: [lib, bin]
📄 Watching extensions: [.dart]

💡 Commands available:
  r + Enter: Hot reload (preserves state)
  R + Enter: Hot restart (full restart)  
  q + Enter: Quit

🌐 Server running on http://127.0.0.1:8080
```

### Commands

- **`r` + Enter**: Hot reload - Preserves application state, faster
- **`R` + Enter**: Hot restart - Full application restart, more reliable  
- **`q` + Enter**: Quit the development server

### Auto Mode Behavior

The package always uses **auto mode** (like Flutter), which:

1. **Tries hot reload first** - Attempts to preserve state using Dart VM service
2. **Falls back to hot restart** - If hot reload fails or isn't available
3. **Provides feedback** - Shows which mode was used and why

## How It Works

### True Hot Reload ✨
- **Uses Dart VM Service's `reloadSources()` API** - Updates code in the running process
- **Preserves application state** - Variables, connections, and server instances remain intact
- **Same port, same PID** - Server continues running without interruption
- **Requires `--enable-vm-service` flag** - Automatically enabled by the package
- **Similar to Flutter's hot reload** - Instant code updates with state preservation

### Hot Restart 🔄
- **Terminates and restarts the entire Dart process** - Fresh compilation and clean state
- **Loses all application state** - Variables reset, connections closed, new server instance
- **New port, new PID** - Complete process restart
- **More compatible across different scenarios** - Guaranteed to pick up all code changes
- **Used as fallback** - When hot reload fails or for structural changes

### Automatic Fallback
The package intelligently chooses the best reload method:

```
📝 File changed: lib/server.dart
🔥 Performing true hot reload...
✅ Hot reload completed - code updated in running process!
```

For structural changes that can't be hot reloaded:
```
📝 File changed: lib/server.dart
🔥 Performing true hot reload...
❌ Hot reload failed: Structural changes detected
🔄 Hot reload not available, performing hot restart...
🔄 Performing true hot restart (restarting entire process)...
✅ Hot restart completed
```

## Configuration Options

### `DeveloperTools.start()` Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `script` | `Function` | **required** | Your application entry point |
| `watchPaths` | `List<String>` | `['lib']` | Directories to watch for changes |
| `watchExtensions` | `List<String>` | `['.dart']` | File extensions to monitor |
| `ignorePatterns` | `List<String>` | See below | Patterns to ignore |
| `debounceDelay` | `Duration` | `500ms` | Delay before triggering reload |
| `verbose` | `bool` | `false` | Enable detailed logging |

### Default Ignore Patterns

```dart
[
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
]
```

## Examples

### Simple HTTP Server

```dart
import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: () async {
      final server = await HttpServer.bind('127.0.0.1', 8080);
      
      await for (final request in server) {
        request.response
          ..headers.contentType = ContentType.html
          ..write('''
            <h1>Hot Reload Demo</h1>
            <p>Time: ${DateTime.now()}</p>
            <p>Try editing this file!</p>
          ''')
          ..close();
      }
    },
  );
}
```

### Console Application

```dart
import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: () async {
      print('🚀 Console app with hot reload');
      print('Current time: ${DateTime.now()}');
      
      // Keep running
      await stdin.first;
    },
    verbose: true,
  );
}
```

## Migration from HttpDev

If you were using `HttpDev` from `utopia_http`:

### Before (HttpDev)
```dart
import 'package:utopia_http/utopia_http.dart';

void main() async {
  await HttpDev.start(
    script: () => runServer(),
    watchPaths: ['lib'],
  );
}
```

### After (DeveloperTools)
```dart
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: () => runServer(),
    watchPaths: ['lib'],
  );
}
```

## Requirements

- Dart SDK 2.17.0 or higher
- For hot reload: Dart VM service support (automatically enabled)

## Troubleshooting

### Hot Reload Not Working

If hot reload consistently fails:

1. **Check for structural changes** - Hot reload can't handle class/method signature changes
2. **Use hot restart** - Press `R` + Enter for structural changes
3. **Enable verbose mode** - Set `verbose: true` to see detailed error messages

### File Changes Not Detected

1. **Check watch paths** - Ensure your files are in the specified `watchPaths`
2. **Check extensions** - Make sure file extensions are in `watchExtensions`
3. **Check ignore patterns** - Verify files aren't excluded by `ignorePatterns`

### Performance Issues

1. **Reduce watch scope** - Watch only necessary directories
2. **Increase debounce delay** - Set higher `debounceDelay` for slower systems
3. **Add ignore patterns** - Exclude large directories like `node_modules`

## Advanced Usage

### Custom Error Handling

The auto mode provides automatic fallback, but you can also handle specific scenarios:

```dart
await DeveloperTools.start(
  script: () async {
    try {
      // Your application code
    } catch (e) {
      print('Application error: $e');
      // Handle gracefully
    }
  },
  verbose: true, // See detailed reload information
);
```

### Multiple File Types

```dart
await DeveloperTools.start(
  script: () => runServer(),
  watchPaths: ['lib', 'web', 'config'],
  watchExtensions: ['.dart', '.yaml', '.json'],
);
```

## License

MIT License - see LICENSE file for details.
