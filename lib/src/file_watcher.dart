import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'reload_mode.dart';

/// File watcher that monitors changes and triggers callbacks
class HotReloadFileWatcher {
  final ReloadConfig config;
  final List<StreamSubscription> _watchers = [];
  Timer? _debounceTimer;

  HotReloadFileWatcher(this.config);

  /// Start watching for file changes
  Future<void> start(Function(String filePath) onFileChanged) async {
    print('👁️  Setting up file watchers...');

    for (final path in config.watchPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        print('👁️  Watching directory: ${dir.absolute.path}');

        final watcher = dir.watch(recursive: true).listen((event) {
          final filePath = event.path;

          if (config.verbose) {
            print(
                '📁 File event: ${event.type} - ${_getRelativePath(filePath)}');
          }

          // Check if file should be watched
          if (!_shouldWatchFile(filePath)) {
            if (config.verbose) {
              print(
                  '⏭️  Skipping file (extension): ${_getRelativePath(filePath)}');
            }
            return;
          }

          // Check ignore patterns
          if (_shouldIgnoreFile(filePath)) {
            if (config.verbose) {
              print(
                  '⏭️  Skipping file (ignored): ${_getRelativePath(filePath)}');
            }
            return;
          }

          // Debug: Print what got through the filters
          if (config.verbose) {
            print('✅ File passed filters: ${_getRelativePath(filePath)}');
          }

          // Debounce file changes
          _debounceTimer?.cancel();
          _debounceTimer = Timer(config.debounceDelay, () {
            final relativePath = _getRelativePath(filePath);
            print('📝 File changed: $relativePath');
            onFileChanged(filePath);
          });
        }, onError: (error) {
          print('❌ File watcher error for $path: $error');
        });

        _watchers.add(watcher);
      } else {
        print('⚠️  Watch path does not exist: $path');
      }
    }

    if (_watchers.isEmpty) {
      throw StateError('No valid watch paths found or no watchers started');
    }

    print('✅ Started ${_watchers.length} file watcher(s)');
  }

  /// Stop watching for file changes
  Future<void> stop() async {
    _debounceTimer?.cancel();
    for (final watcher in _watchers) {
      await watcher.cancel();
    }
    _watchers.clear();
  }

  /// Check if a file should be watched based on extensions
  bool _shouldWatchFile(String filePath) {
    for (final ext in config.watchExtensions) {
      if (filePath.endsWith(ext)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a file should be ignored based on patterns
  bool _shouldIgnoreFile(String filePath) {
    final relativePath =
        path.normalize(_getRelativePathFromWatchPaths(filePath));

    for (final pattern in config.ignorePatterns) {
      final normalizedPattern = path.normalize(pattern);

      // Handle glob-like patterns
      if (normalizedPattern.startsWith('**') &&
          normalizedPattern.endsWith('**')) {
        final innerPattern =
            normalizedPattern.substring(2, normalizedPattern.length - 2);
        if (relativePath.contains(innerPattern)) {
          return true;
        }
      } else if (normalizedPattern.contains('*')) {
        // Simple wildcard matching
        final regexPattern =
            normalizedPattern.replaceAll('.', r'\.').replaceAll('*', '.*');
        if (RegExp(regexPattern).hasMatch(relativePath)) {
          return true;
        }
      } else {
        // Simple string matching - normalize both paths for comparison
        if (path
            .normalize(relativePath)
            .contains(path.normalize(normalizedPattern))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get relative path from the watch paths (for ignore pattern matching)
  String _getRelativePathFromWatchPaths(String filePath) {
    // Normalize the file path
    final normalizedFilePath = path.normalize(path.absolute(filePath));

    // Try to find the relative path from any of the watch paths
    for (final watchPath in config.watchPaths) {
      final normalizedWatchPath = path.normalize(path.absolute(watchPath));

      // Check if the file is within this watch path
      if (normalizedFilePath.startsWith(normalizedWatchPath + path.separator) ||
          normalizedFilePath == normalizedWatchPath) {
        // Calculate relative path
        final relativePath =
            normalizedFilePath.substring(normalizedWatchPath.length);
        // Remove leading separator if present
        if (relativePath.startsWith(path.separator)) {
          return relativePath.substring(1);
        }
        return relativePath;
      }
    }

    // Fallback: try to get relative path from current directory
    try {
      return path.relative(normalizedFilePath);
    } catch (e) {
      // Last resort: return just the filename
      return path.basename(filePath);
    }
  }

  /// Get relative path for display
  String _getRelativePath(String filePath) {
    try {
      return path.relative(path.normalize(filePath), from: path.current);
    } catch (e) {
      // Fallback to original path if relative calculation fails
      return filePath;
    }
  }
}
