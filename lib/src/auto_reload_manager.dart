import 'dart:async';
import 'dart:io';

import 'reload_mode.dart';
import 'file_watcher.dart';

/// Auto reload manager that tries hot reload first, then falls back to hot restart
/// This mimics Flutter's behavior where it tries to preserve state first
class AutoReloadManager {
  final Future<void> Function() script;
  final ReloadConfig config;
  late final HotReloadFileWatcher _fileWatcher;
  StreamSubscription? _fileSubscription;
  StreamSubscription? _stdinSubscription;
  Process? _currentProcess;
  bool _isReloading = false;

  AutoReloadManager({
    required this.script,
    required this.config,
  }) {
    _fileWatcher = HotReloadFileWatcher(config);
  }

  Future<void> start() async {
    print('🚀 Starting application with auto hot reload...');
    print('📁 Watching paths: ${config.watchPaths}');
    print('📄 Watching extensions: ${config.watchExtensions}');
    print('');
    print('💡 Commands available:');
    print('  r + Enter: Hot reload (preserves state)');
    print('  R + Enter: Hot restart (full restart)');
    print('  q + Enter: Quit');
    print('');

    // Start the application initially
    await _startApplication();

    // Listen for file changes
    await _fileWatcher.start((path) async {
      if (_isReloading) return;
      print('📝 File changed: ${_getRelativePath(path)}');
      await _performAutoReload();
    });

    // Listen for keyboard commands (r, R, q)
    stdin.echoMode = false;
    stdin.lineMode = false;
    _stdinSubscription = stdin.listen((data) {
      final char = String.fromCharCode(data.first);
      switch (char) {
        case 'r':
          print('🔥 Manual hot reload triggered...');
          _performHotReload();
          break;
        case 'R':
          print('🔄 Manual hot restart triggered...');
          _performHotRestart();
          break;
        case 'q':
          print('👋 Shutting down...');
          _shutdown();
          break;
      }
    });

    // Handle Ctrl+C gracefully
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\\n🛑 Shutting down development server...');
      await _shutdown();
      exit(0);
    });

    // Keep the process alive
    await Completer().future;
  }

  Future<void> _startApplication() async {
    try {
      await script();
    } catch (e) {
      print('❌ Error starting application: $e');
      rethrow;
    }
  }

  Future<void> _performAutoReload() async {
    if (_isReloading) return;
    _isReloading = true;

    try {
      // Try hot reload first (preserves state)
      final hotReloadSuccess = await _performHotReload();

      if (!hotReloadSuccess) {
        print('🔄 Hot reload not available, performing hot restart...');
        await _performHotRestart();
      }
    } finally {
      _isReloading = false;
    }
  }

  Future<bool> _performHotReload() async {
    try {
      // For now, hot reload is not fully implemented, so always return false
      // This will be implemented when VM service integration is ready
      print('ℹ️  Hot reload not yet available, falling back to hot restart');
      return false;
    } catch (e) {
      if (config.verbose) {
        print('❌ Hot reload failed: $e');
      }
      return false;
    }
  }

  Future<void> _performHotRestart() async {
    try {
      print('🔄 Performing hot restart...');

      // Kill existing process if any
      if (_currentProcess != null) {
        _currentProcess!.kill();
        await _currentProcess!.exitCode;
        _currentProcess = null;
      }

      // Restart the application
      await _startApplication();
      print('✅ Hot restart completed');
    } catch (e) {
      print('❌ Hot restart failed: $e');
      rethrow;
    }
  }

  String _getRelativePath(String fullPath) {
    final currentDir = Directory.current.path;
    if (fullPath.startsWith(currentDir)) {
      return fullPath.substring(currentDir.length + 1);
    }
    return fullPath;
  }

  Future<void> _shutdown() async {
    await _fileSubscription?.cancel();
    await _stdinSubscription?.cancel();
    await _fileWatcher.stop();
    if (_currentProcess != null) {
      _currentProcess!.kill();
      await _currentProcess!.exitCode;
    }
    exit(0);
  }
}
