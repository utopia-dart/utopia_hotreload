# Utopia Hot Reload

Advanced hot reload and hot restart for Dart server and CLI applications, with a Flutter-like development experience.

[![Pub Version](https://img.shields.io/pub/v/utopia_hotreload)](https://pub.dev/packages/utopia_hotreload)
[![Dart SDK Version](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **True Hot Reload** - Uses Dart VM service to reload code while preserving application state
- **Hot Restart** - Full process restart when hot reload isn't possible
- **Auto Mode** - Tries hot reload first, falls back to restart automatically
- **File Watching** - Configurable paths, extensions, and debouncing
- **CLI Tool** - Zero-config hot reload for any Dart script
- **Config File** - Project-wide settings via `hotreload.yaml`
- **Lifecycle Hooks** - Callbacks for reload/restart events
- **Multi-Service** - Run multiple services with coordinated reload
- **Web Dashboard** - Real-time monitoring and metrics
- **WSL2 Support** - Auto-detects and uses polling on mounted Windows drives

## Installation

```yaml
dev_dependencies:
  utopia_hotreload: ^3.0.0
```

## Quick Start

### Option 1: CLI (zero config)

Run any Dart script with hot reload — no code changes needed:

```bash
dart run utopia_hotreload bin/server.dart
```

### Option 2: Programmatic API

```dart
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: () async {
      final server = await HttpServer.bind('localhost', 8080);
      print('Server running on http://localhost:8080');
      await for (final request in server) {
        request.response
          ..write('Hello! Time: ${DateTime.now()}')
          ..close();
      }
    },
  );
}
```

That's it. Edit your code, save, and see changes applied instantly.

## Interactive Commands

While running:

| Key | Action |
|-----|--------|
| `r` | Hot reload (preserves state) |
| `R` | Hot restart (full restart) |
| `q` | Quit |

## Configuration

There are three ways to configure hot reload, and they layer on top of each other:

### Precedence Order

```
Code parameters  >  hotreload.yaml  >  Built-in defaults
```

1. **Parameters passed to `DeveloperTools.start()`** always win
2. **`hotreload.yaml`** provides project-wide defaults (auto-loaded)
3. **Built-in defaults** are used when nothing else is specified

### Using `hotreload.yaml` (recommended)

Create a `hotreload.yaml` in your project root:

```yaml
# Directories to watch
watch_paths:
  - lib
  - bin

# File extensions to monitor
watch_extensions:
  - .dart
  - .yaml

# Patterns to ignore
ignore_patterns:
  - .git/
  - .dart_tool/
  - build/

# Reload mode: auto, hotReload, or hotRestart
mode: auto

# Debounce delay in milliseconds
debounce_ms: 500

# Verbose logging
verbose: false

# Web dashboard
dashboard:
  enabled: false
  port: 9000

# VM service port (null = auto)
# vm_service_port: 8181

# Polling-based file watcher (for WSL2/network drives)
# use_polling: true
# polling_delay_ms: 1000
```

Then your code just needs:

```dart
void main() async {
  await DeveloperTools.start(
    script: () async {
      // Your app code
    },
  );
}
```

`DeveloperTools.start()` automatically loads `hotreload.yaml` from the project root. No manual loading needed.

### Using code parameters only

If you don't want a config file, pass everything directly:

```dart
await DeveloperTools.start(
  script: () async { /* ... */ },
  watchPaths: ['lib', 'bin'],
  watchExtensions: ['.dart', '.yaml'],
  debounceDelay: Duration(milliseconds: 300),
  verbose: true,
);
```

### Mixing both (overriding specific values)

Use `hotreload.yaml` for project-wide defaults and override specific values in code:

```yaml
# hotreload.yaml
watch_paths:
  - lib
  - bin
verbose: false
debounce_ms: 500
```

```dart
await DeveloperTools.start(
  script: () async { /* ... */ },
  verbose: true,  // overrides yaml's false
  // watch_paths and debounce come from hotreload.yaml
);
```

Only the parameters you explicitly pass will override the YAML values.

### Custom config file path

```dart
await DeveloperTools.start(
  script: () async { /* ... */ },
  configFile: 'config/dev.yaml',
);
```

## CLI Usage

```bash
# Basic usage
dart run utopia_hotreload bin/server.dart

# Watch multiple directories
dart run utopia_hotreload -w lib -w bin bin/server.dart

# Custom extensions and verbose mode
dart run utopia_hotreload -e .dart,.yaml --verbose bin/server.dart

# Pass arguments to your script
dart run utopia_hotreload bin/server.dart -- --port 8080
```

The CLI also loads `hotreload.yaml` automatically if present.

| Option | Short | Default | Description |
|--------|-------|---------|-------------|
| `--watch` | `-w` | `lib` | Directories to watch (repeatable) |
| `--ext` | `-e` | `.dart` | Extensions to watch (comma-separated) |
| `--debounce` | | `500` | Debounce delay in milliseconds |
| `--verbose` | `-v` | `false` | Enable verbose logging |
| `--help` | `-h` | | Show help message |

## Lifecycle Hooks

React to reload and restart events:

```dart
await DeveloperTools.start(
  script: () async { /* ... */ },
  hooks: LifecycleHooks(
    onBeforeReload: () async {
      print('About to reload...');
      return true; // return false to cancel the reload
    },
    onAfterReload: () async {
      print('Reload complete!');
    },
    onBeforeRestart: () async {
      print('Closing connections before restart...');
    },
    onAfterRestart: () async {
      print('Restarted!');
    },
    onFileChanged: (path) async {
      print('File changed: $path');
    },
    onError: (error) async {
      print('Reload error: $error');
    },
  ),
);
```

## Web Dashboard

Enable the built-in web dashboard for real-time monitoring:

```dart
await DeveloperTools.start(
  script: () async { /* ... */ },
  enableDashboard: true,
  dashboardPort: 9000,
);
```

Or in `hotreload.yaml`:

```yaml
dashboard:
  enabled: true
  port: 9000
```

The dashboard provides live metrics, reload history, file watching status, and service management at `http://localhost:9000`.

## Multi-Service Development

Run multiple services simultaneously with coordinated reload:

```dart
await DeveloperTools.startMultiple([
  ServiceConfig(
    name: 'api',
    script: () async { /* API server */ },
    watchPaths: ['lib/api'],
  ),
  ServiceConfig(
    name: 'web',
    script: () async { /* Web server */ },
    watchPaths: ['lib/web'],
  ),
]);
```

Each service gets its own VM service connection for independent hot reload.

## WSL2 / Network Drives

On WSL2, native file watching (`inotify`) doesn't work on mounted Windows drives (`/mnt/`). The package auto-detects this and switches to polling.

To force polling manually:

```dart
await DeveloperTools.start(
  script: () async { /* ... */ },
  usePolling: true,
);
```

Or in `hotreload.yaml`:

```yaml
use_polling: true
polling_delay_ms: 1000
```

## How It Works

1. **Hot Reload** - Uses `vm_service` `reloadSources()` API to update code in the running process. Variables, connections, and server instances remain intact. Same port, same PID.

2. **Hot Restart** - Terminates and restarts the Dart process. Clean state, new connections. Used as fallback when hot reload fails.

3. **Auto Mode** (default) - Tries hot reload first. If it fails (e.g., structural changes), automatically falls back to hot restart.

## `DeveloperTools.start()` Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `script` | `Future<void> Function()` | required | Your application entry point |
| `watchPaths` | `List<String>?` | YAML or `['lib']` | Directories to watch |
| `watchExtensions` | `List<String>?` | YAML or `['.dart']` | File extensions to monitor |
| `ignorePatterns` | `List<String>?` | YAML or common patterns | Patterns to ignore |
| `debounceDelay` | `Duration?` | YAML or `500ms` | Delay before triggering reload |
| `verbose` | `bool?` | YAML or `false` | Enable detailed logging |
| `enableDashboard` | `bool?` | YAML or `false` | Enable web dashboard |
| `dashboardPort` | `int?` | YAML or `9000` | Dashboard port |
| `usePolling` | `bool?` | YAML or auto-detect | Force polling file watcher |
| `configFile` | `String?` | `hotreload.yaml` | Custom config file path |
| `hooks` | `LifecycleHooks?` | none | Reload/restart callbacks |
| `childVmServicePort` | `int?` | YAML or auto | VM service port |

## Requirements

- Dart SDK 3.0.0 or higher

## License

MIT License - see LICENSE file for details.
