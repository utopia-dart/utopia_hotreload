import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'reload_mode.dart';

/// Monitors file system changes and triggers reload callbacks.
///
/// Provides intelligent filtering based on file extensions, ignore patterns,
/// and debouncing to prevent excessive reload triggers during rapid file saves.
class HotReloadFileWatcher {
  final ReloadConfig config;
  final List<StreamSubscription> _watchers = [];
  Timer? _debounceTimer;

  /// Creates a new file watcher with the given [config].
  HotReloadFileWatcher(this.config);

  /// Starts watching for file changes and calls [onFileChanged] when relevant files are modified.
  ///
  /// Only files matching [config.watchExtensions] and not matching [config.ignorePatterns]
  /// will trigger the callback. Changes are debounced using [config.debounceDelay].
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

          if (!_shouldWatchFile(filePath)) {
            if (config.verbose) {
              print(
                  '⏭️  Skipping file (extension): ${_getRelativePath(filePath)}');
            }
            return;
          }

          if (_shouldIgnoreFile(filePath)) {
            if (config.verbose) {
              print(
                  '⏭️  Skipping file (ignored): ${_getRelativePath(filePath)}');
            }
            return;
          }
          if (config.verbose) {
            print('✅ File passed filters: ${_getRelativePath(filePath)}');
          }

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

  /// Stops watching for file changes and cleans up resources.
  Future<void> stop() async {
    _debounceTimer?.cancel();
    for (final watcher in _watchers) {
      await watcher.cancel();
    }
    _watchers.clear();
  }

  /// Returns `true` if the file should be watched based on its extension.
  bool _shouldWatchFile(String filePath) {
    for (final ext in config.watchExtensions) {
      if (filePath.endsWith(ext)) {
        return true;
      }
    }
    return false;
  }

  /// Returns `true` if the file should be ignored based on ignore patterns.
  bool _shouldIgnoreFile(String filePath) {
    final relativePath =
        path.normalize(_getRelativePathFromWatchPaths(filePath));

    for (final pattern in config.ignorePatterns) {
      final normalizedPattern = path.normalize(pattern);

      if (normalizedPattern.startsWith('**') &&
          normalizedPattern.endsWith('**')) {
        final innerPattern =
            normalizedPattern.substring(2, normalizedPattern.length - 2);
        if (relativePath.contains(innerPattern)) {
          return true;
        }
      } else if (normalizedPattern.contains('*')) {
        final regexPattern =
            normalizedPattern.replaceAll('.', r'\.').replaceAll('*', '.*');
        if (RegExp(regexPattern).hasMatch(relativePath)) {
          return true;
        }
      } else {
        if (path
            .normalize(relativePath)
            .contains(path.normalize(normalizedPattern))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns the relative path from the watch paths for ignore pattern matching.
  String _getRelativePathFromWatchPaths(String filePath) {
    final normalizedFilePath = path.normalize(path.absolute(filePath));

    for (final watchPath in config.watchPaths) {
      final normalizedWatchPath = path.normalize(path.absolute(watchPath));

      if (normalizedFilePath.startsWith(normalizedWatchPath + path.separator) ||
          normalizedFilePath == normalizedWatchPath) {
        final relativePath =
            normalizedFilePath.substring(normalizedWatchPath.length);
        if (relativePath.startsWith(path.separator)) {
          return relativePath.substring(1);
        }
        return relativePath;
      }
    }

    try {
      return path.relative(normalizedFilePath);
    } catch (e) {
      return path.basename(filePath);
    }
  }

  /// Returns a relative path from the current directory for display purposes.
  String _getRelativePath(String filePath) {
    try {
      return path.relative(path.normalize(filePath), from: path.current);
    } catch (e) {
      return filePath;
    }
  }
}
