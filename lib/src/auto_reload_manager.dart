import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

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

  // VM Service for true hot reload
  VmService? _vmService;
  String? _isolateId;
  bool _vmServiceEnabled = false;

  // Application cleanup callbacks
  static final List<Function()> _cleanupCallbacks = [];

  /// Register a cleanup callback that will be called on shutdown
  static void registerCleanupCallback(Future<void> Function() callback) {
    _cleanupCallbacks.add(callback);
  }

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

    // Set up file watching BEFORE starting the application
    await _fileWatcher.start((path) async {
      if (_isReloading) return;
      print('📝 File changed: ${_getRelativePath(path)}');
      await _performAutoReload();
    });

    // Try to enable VM service for true hot reload
    await _initializeVmService();

    // Set up non-interactive background keyboard commands
    print('🎮 Background keyboard input enabled...');
    print('💡 Press: r (reload), R (restart), q (quit), or Ctrl+C');

    // Safe background stdin setup - avoid crashes on cleanup
    bool rawMode = false;

    // Try raw mode: single-keystroke, no echo, non-blocking (all platforms; fallback on error)
    if (stdin.hasTerminal) {
      try {
        stdin.echoMode = false;
        stdin.lineMode = false;
        rawMode = true;
      } catch (e) {
        // Terminal may not support raw mode (e.g., some Windows shells/CI)
        rawMode = false;
      }
    }

    // Background stdin listener (does not block main application)
    if (rawMode) {
      _stdinSubscription = stdin.listen((data) {
        for (final byte in data) {
          final char = String.fromCharCode(byte);
          // Handle Ctrl+C (ETX) when in raw mode
          if (byte == 3) {
            print('\n🛑 Ctrl+C detected - shutting down development server...');
            _shutdown();
            return;
          }
          switch (char) {
            case 'r':
              print('\n🔥 Manual hot reload triggered...');
              _performHotReload();
              break;
            case 'R':
              print('\n🔄 Manual hot restart triggered...');
              _performHotRestart();
              break;
            case 'q':
            case 'Q':
              print('\n👋 Shutting down via keyboard command...');
              _shutdown();
              return;
          }
        }
      }, onError: (error) {
        // Silently handle stdin errors
      }, cancelOnError: false);
    } else {
      // Fallback to line-based mode for terminals that don't support raw mode
      _stdinSubscription = stdin
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final command = line.trim();
        switch (command) {
          case 'r':
            print('🔥 Manual hot reload triggered...');
            _performHotReload();
            break;
          case 'R':
            print('🔄 Manual hot restart triggered...');
            _performHotRestart();
            break;
          case 'q':
          case 'Q':
          case 'quit':
          case 'exit':
            print('👋 Shutting down via keyboard command...');
            _shutdown();
            break;
          default:
            switch (command.toLowerCase()) {
              case 'r':
                print('🔥 Manual hot reload triggered...');
                _performHotReload();
                break;
              case 'q':
              case 'quit':
              case 'exit':
                print('👋 Shutting down via keyboard command...');
                _shutdown();
                break;
            }
        }
      }, onError: (error) {
        // Silently handle stdin errors
      }, cancelOnError: false);
    }

    // Handle Ctrl+C gracefully with immediate shutdown
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\n🛑 Ctrl+C detected - shutting down development server...');
      await _shutdown();
      // Force exit if shutdown doesn't work
      exit(0);
    });

    // Also handle SIGTERM to ensure cleanup on termination (skip on Windows)
    try {
      if (!Platform.isWindows) {
        ProcessSignal.sigterm.watch().listen((signal) async {
          print('\n🛑 SIGTERM received - shutting down development server...');
          await _shutdown();
          exit(0);
        });
      }
    } catch (_) {
      // Platform may not support SIGTERM; ignore
    }

    // Start the application AFTER setting up watchers
    await _startApplication();

    // Keep the process alive
    await Completer().future;
  }

  Future<void> _startApplication() async {
    try {
      await script();
    } catch (e) {
      print('❌ Error starting application: $e');
      if (config.verbose) {
        print('   Stack trace: ${StackTrace.current}');
      }
      // Don't rethrow in auto-reload mode, just log the error
      print('   Application will retry on next reload...');
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
      if (!_vmServiceEnabled || _vmService == null || _isolateId == null) {
        if (config.verbose) {
          print('ℹ️  VM Service not available, cannot perform true hot reload');
        }
        return false;
      }

      print('🔥 Performing true hot reload...');

      // Use VM service to reload sources
      final reloadReport = await _vmService!.reloadSources(_isolateId!);

      if (reloadReport.success == true) {
        print('✅ Hot reload completed - code updated in running process!');
        return true;
      } else {
        print('❌ Hot reload failed');
        if (config.verbose && reloadReport.json != null) {
          print('   Response: ${reloadReport.json}');
        }
        return false;
      }
    } catch (e) {
      if (config.verbose) {
        print('❌ Hot reload failed: $e');
      }
      return false;
    }
  }

  Future<void> _performHotRestart() async {
    try {
      print('🔄 Performing true hot restart (restarting entire process)...');

      // For true hot restart, we need to restart the entire Dart process
      // We'll use the same approach as HotRestartManager but adapted for this context

      if (Platform.environment['UTOPIA_DEV_CHILD'] == 'true') {
        // We're in a child process, exit and let parent restart us
        print('🔄 Exiting child process for restart...');
        exit(0);
      } else {
        // We're in the main process, need to restart ourselves
        await _restartMainProcess();
      }
    } catch (e) {
      print('❌ Hot restart failed: $e');
      if (config.verbose) {
        print('   Error details: $e');
      }
    }
  }

  /// Initialize VM service for true hot reload
  Future<void> _initializeVmService() async {
    try {
      // Check if VM service is already enabled
      final serviceInfo = await developer.Service.getInfo();
      if (serviceInfo.serverUri != null) {
        final wsUri =
            serviceInfo.serverUri.toString().replaceFirst('http', 'ws');
        if (config.verbose) {
          print('🔌 Connecting to VM service: $wsUri');
        }

        _vmService = await vmServiceConnectUri(wsUri);

        // Get the main isolate
        final vm = await _vmService!.getVM();
        if (vm.isolates?.isNotEmpty == true) {
          _isolateId = vm.isolates!.first.id!;
          _vmServiceEnabled = true;

          print('✅ VM Service connected - true hot reload enabled!');
          if (config.verbose) {
            print('   Isolate ID: $_isolateId');
          }
        }
      } else {
        print(
            '⚠️  VM Service not available - falling back to hot restart only');
        print(
            '   To enable true hot reload, start with: dart --enable-vm-service your_script.dart');
      }
    } catch (e) {
      if (config.verbose) {
        print('⚠️  Failed to connect to VM service: $e');
      }
      print('   True hot reload not available, using hot restart fallback');
      _vmServiceEnabled = false;
    }
  }

  /// Restart the main process for true hot restart
  Future<void> _restartMainProcess() async {
    print('🔄 Restarting main process...');

    // Get current script path and arguments
    final scriptPath = Platform.script.toFilePath();
    final args = List<String>.from(Platform.executableArguments);

    // Start new process
    final process = await Process.start(
      Platform.executable,
      [...args, scriptPath],
      mode: ProcessStartMode.detached,
    );

    print('✅ New process started (PID: ${process.pid})');
    print('🛑 Shutting down current process...');

    // Exit current process
    exit(0);
  }

  String _getRelativePath(String fullPath) {
    final currentDir = Directory.current.path;
    if (fullPath.startsWith(currentDir)) {
      return fullPath.substring(currentDir.length + 1);
    }
    return fullPath;
  }

  Future<void> _shutdown() async {
    print('🛑 Shutting down development server...');

    // Cancel subscriptions first
    await _fileSubscription?.cancel();
    await _stdinSubscription?.cancel();
    await _fileWatcher.stop();

    // Safely restore terminal settings before any other cleanup (skip on Windows to avoid VM crash)
    if (!Platform.isWindows) {
      try {
        if (stdin.hasTerminal) {
          stdin.echoMode = true;
          stdin.lineMode = true;
        }
      } catch (e) {
        // Ignore terminal restoration errors to avoid crashes
      }
    }

    // Call application cleanup callbacks
    for (final callback in _cleanupCallbacks) {
      try {
        await callback();
      } catch (e) {
        print('⚠️  Cleanup callback error: $e');
      }
    }

    // Clean up VM service connection
    if (_vmService != null) {
      try {
        await _vmService!.dispose();
      } catch (e) {
        // Ignore VM service cleanup errors
      }
    }

    if (_currentProcess != null) {
      print('   Stopping child process...');
      _currentProcess!.kill();
      try {
        await _currentProcess!.exitCode.timeout(Duration(seconds: 2));
      } catch (e) {
        // Force kill if it doesn't stop gracefully
        _currentProcess!.kill(ProcessSignal.sigkill);
      }
    }

    print('✅ Development server stopped');
    exit(0);
  }
}
