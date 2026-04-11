import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';

import 'reload_config.dart';
import 'file_pattern_matcher.dart';

/// Monitors file system changes and triggers reload callbacks.
///
/// Provides intelligent filtering based on file extensions, ignore patterns,
/// advanced pattern matching, and debouncing to prevent excessive reload triggers.
///
/// Automatically detects environments where native file watching doesn't work
/// (e.g., WSL2 mounted Windows drives) and falls back to polling.
class HotReloadFileWatcher {
  final ReloadConfig config;
  final List<StreamSubscription> _watchers = [];
  Timer? _debounceTimer;
  late final FilePatternMatcher _patternMatcher;

  static bool? _usePollingCached;

  /// Creates a new file watcher with the given [config].
  HotReloadFileWatcher(this.config) {
    _patternMatcher = config.effectivePatternMatcher;
  }

  /// Detects if polling mode should be used instead of native file watching.
  ///
  /// Returns true on WSL2 with mounted Windows drives, where inotify
  /// doesn't deliver events for /mnt/ paths.
  static bool _shouldUsePolling(String watchPath) {
    if (_usePollingCached != null) return _usePollingCached!;

    if (!Platform.isLinux) {
      _usePollingCached = false;
      return false;
    }

    try {
      final procVersion = File('/proc/version').readAsStringSync();
      if (procVersion.toLowerCase().contains('microsoft')) {
        final absPath = path.normalize(path.absolute(watchPath));
        if (absPath.startsWith('/mnt/')) {
          _usePollingCached = true;
          return true;
        }
      }
    } catch (_) {}

    _usePollingCached = false;
    return false;
  }

  /// Starts watching for file changes and calls [onFileChanged] when relevant files are modified.
  ///
  /// Uses advanced pattern matching if configured, otherwise falls back to
  /// extension-based filtering and ignore patterns. Changes are debounced using [config.debounceDelay].
  Future<void> start(Function(String filePath) onFileChanged) async {
    print('👁️  Setting up file watchers...');

    for (final watchPathStr in config.watchPaths) {
      final dir = Directory(watchPathStr);
      if (await dir.exists()) {
        final absPath = dir.absolute.path;
        final usePolling = config.usePolling ?? _shouldUsePolling(absPath);

        if (usePolling) {
          print('👁️  Watching directory (polling): $absPath');
        } else {
          print('👁️  Watching directory: $absPath');
        }

        final DirectoryWatcher directoryWatcher;
        if (usePolling) {
          directoryWatcher = PollingDirectoryWatcher(absPath,
              pollingDelay: config.pollingDelay);
        } else {
          directoryWatcher = DirectoryWatcher(absPath);
        }

        final watcher = directoryWatcher.events.listen((event) {
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
          print('❌ File watcher error for ${dir.path}: $error');
        });

        _watchers.add(watcher);
      } else {
        print('⚠️  Watch path does not exist: $watchPathStr');
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

  /// Gets information about what files and patterns are being watched.
  Map<String, dynamic> getWatchInfo() {
    return {
      'watchPaths': config.watchPaths,
      'watchExtensions': config.watchExtensions,
      'ignorePatterns': config.ignorePatterns,
      'isActive': _watchers.isNotEmpty,
      'matcherInfo': _patternMatcher.getMatcherInfo(),
      'debounceMs': config.debounceDelay.inMilliseconds,
      'verbose': config.verbose,
    };
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
