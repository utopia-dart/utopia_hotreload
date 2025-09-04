import 'dart:async';
import 'dart:io';

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
    final relativePath = _getRelativePath(filePath);

    for (final pattern in config.ignorePatterns) {
      // Handle glob-like patterns
      if (pattern.startsWith('**') && pattern.endsWith('**')) {
        final innerPattern = pattern.substring(2, pattern.length - 2);
        if (relativePath.contains(innerPattern)) {
          return true;
        }
      } else if (pattern.contains('*')) {
        // Simple wildcard matching
        final regexPattern =
            pattern.replaceAll('.', '\\.').replaceAll('*', '.*');
        if (RegExp(regexPattern).hasMatch(relativePath)) {
          return true;
        }
      } else {
        // Simple string matching
        if (relativePath.contains(pattern)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get relative path for display
  String _getRelativePath(String filePath) {
    final currentDir = Directory.current.path;
    if (filePath.startsWith(currentDir)) {
      String relativePath = filePath.substring(currentDir.length);
      if (relativePath.startsWith(Platform.pathSeparator)) {
        relativePath = relativePath.substring(1);
      }
      return relativePath;
    }
    return filePath;
  }
}
