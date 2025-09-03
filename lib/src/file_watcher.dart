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
    for (final path in config.watchPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        if (config.verbose) {
          print('👁️  Watching directory: ${dir.absolute.path}');
        }

        final watcher = dir.watch(recursive: true).listen((event) {
          final filePath = event.path;

          // Check if file should be watched
          if (!_shouldWatchFile(filePath)) return;

          // Check ignore patterns
          if (_shouldIgnoreFile(filePath)) return;

          // Debounce file changes
          _debounceTimer?.cancel();
          _debounceTimer = Timer(config.debounceDelay, () {
            final relativePath = _getRelativePath(filePath);
            if (config.verbose) {
              print('📝 File changed: $relativePath');
            }
            onFileChanged(filePath);
          });
        });

        _watchers.add(watcher);
      } else {
        if (config.verbose) {
          print('⚠️  Watch path does not exist: $path');
        }
      }
    }

    if (_watchers.isEmpty) {
      throw StateError('No valid watch paths found');
    }
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
    for (final pattern in config.ignorePatterns) {
      if (filePath.contains(pattern)) {
        return true;
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
