# Changelog

All notable changes to the utopia_hotreload package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-09-03

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
