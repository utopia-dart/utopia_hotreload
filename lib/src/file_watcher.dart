import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'reload_mode.dart';
import 'file_pattern_matcher.dart';

/// Monitors file system changes and triggers reload callbacks.
///
/// Provides intelligent filtering based on file extensions, ignore patterns,
/// advanced pattern matching, and debouncing to prevent excessive reload triggers.
class HotReloadFileWatcher {
  final ReloadConfig config;
  final List<StreamSubscription> _watchers = [];
  Timer? _debounceTimer;
  late final FilePatternMatcher _patternMatcher;

  /// Creates a new file watcher with the given [config].
  HotReloadFileWatcher(this.config) {
    _patternMatcher = config.effectivePatternMatcher;
  }

  /// Starts watching for file changes and calls [onFileChanged] when relevant files are modified.
  ///
  /// Uses advanced pattern matching if configured, otherwise falls back to
  /// extension-based filtering and ignore patterns. Changes are debounced using [config.debounceDelay].
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

          // Use advanced pattern matching if available, otherwise use legacy filtering
          final shouldWatch = _shouldWatchFileAdvanced(filePath);

          if (!shouldWatch) {
            if (config.verbose) {
              print('⏭️  Skipping file: ${_getRelativePath(filePath)}');
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

  /// Determines if a file should be watched using advanced pattern matching or legacy filtering.
  bool _shouldWatchFileAdvanced(String filePath) {
    // Get relative path for pattern matching
    final relativePath = _getRelativePathFromWatchPaths(filePath);

    // Use the pattern matcher which combines both include and exclude rules
    return _patternMatcher.matches(relativePath);
  }

  /// Returns a relative path from the watch paths for pattern matching.
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
