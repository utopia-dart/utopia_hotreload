## [2.0.1]

### Bug Fixes
- **WSL2 file watching**: Auto-detect WSL2 mounted Windows drives (`/mnt/`) and use `PollingDirectoryWatcher` since `inotify` doesn't deliver events on those paths
- **Keyboard commands**: `r` (hot reload) and `R` (hot restart) now work correctly — previously both triggered hot restart due to case-insensitive command registration
- Fixed operator precedence bug in YAML config parser for `vm_service_port`
- Fixed unawaited futures in multi-service manager
- Fixed path prefix matching that could produce false positives on overlapping directory names

### New Configuration Options
- `usePolling` (`use_polling` in YAML): Force polling-based file watching, or set to `null` for auto-detection
- `pollingDelay` (`polling_delay_ms` in YAML): Configure polling interval (default: 1 second)

## [2.0.0]

### Breaking Changes
- **Minimum SDK version bumped to Dart 3.0.0** (was 2.17.0)
- Removed unused `meta` dependency

### New Features
- **CLI executable**: Run `dart run utopia_hotreload bin/server.dart` for zero-config hot reload
- **Lifecycle hooks**: `onBeforeReload`, `onAfterReload`, `onBeforeRestart`, `onAfterRestart`, `onFileChanged`, `onError` callbacks via `LifecycleHooks` class
- **Configuration file support**: Load settings from `hotreload.yaml` via `ReloadConfigFile`
- **Fixed multi-service manager**: Services now actually run user code with per-service VM hot reload (was using placeholder scripts)
- **Advanced file pattern matching**: Glob patterns, regex, and predefined presets (`dart-project`, `web-project`, `flutter-project`)

### Improvements
- File watcher now uses `DirectoryWatcher` from the `watcher` package for better cross-platform reliability
- Memory usage detection uses `ProcessInfo.currentRss` instead of shelling out to `tasklist`/`ps`
- Per-service hot reload via VM service `reloadSources()` with restart fallback
- Concurrency guard prevents overlapping service restarts

## [1.0.1]

- Documentation updates
- Cleanup and remove unused libraries

## [1.0.0]

### Added
- Initial release of utopia_hotreload package
- True hot reload functionality using Dart VM service
- Hot restart capability for when hot reload isn't possible
- Auto mode that intelligently chooses between hot reload and hot restart
- File watching system with configurable paths and extensions
- Debouncing support to prevent excessive reload triggers
- Ignore patterns for excluding files/directories from watching
- Comprehensive developer tools API with `DeveloperTools.start()`
- Multiple reload modes: `hotReload`, `hotRestart`, and `auto`
- VM service integration with automatic connection management
- Graceful fallback mechanisms when hot reload fails
- Support for custom script execution and server management
- Built-in error handling and logging for debugging
- State preservation during hot reload (similar to Flutter)
- Process isolation for hot restart functionality

### Features
- **True Hot Reload**: Uses Dart VM service to reload code without losing application state
- **Hot Restart**: Process-based restart for cases where hot reload isn't suitable
- **Auto Mode**: Tries hot reload first, automatically falls back to hot restart
- **File Watching**: Monitors specified directories and file extensions for changes
- **Configurable Debouncing**: Prevents rapid successive reloads from file save bursts
- **Ignore Patterns**: Exclude build directories, generated files, and other unwanted paths
- **Developer-Friendly API**: Simple `DeveloperTools.start()` method for easy integration

### Technical Details
- Requires Dart SDK 2.17.0 or higher
- Uses `vm_service` package for hot reload functionality
- Uses `watcher` package for file system monitoring
- Supports both isolate-based and process-based execution models
- Automatic VM service enablement and connection management
- Graceful error handling with detailed logging for troubleshooting
