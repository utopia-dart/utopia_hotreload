import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'reload_mode.dart';
import 'file_watcher.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Main interface for hot reload/restart functionality.
///
/// This replaces the old HttpDev class and works like Flutter's hot reload,
/// providing a seamless development experience with automatic reloading.
///
/// The DeveloperTools class provides a single entry point for starting
/// a development server with hot reload capabilities.
class DeveloperTools {
  DeveloperTools._();

  /// Start a development server with auto hot reload/restart (like Flutter).
  ///
  /// This automatically tries hot reload first, then falls back to hot restart
  /// if hot reload fails. Just like Flutter's behavior.
  ///
  /// **Parameters:**
  /// - [script]: Your application entry point function
  /// - [watchPaths]: Directories to watch for changes (default: `['lib']`)
  /// - [watchExtensions]: File extensions to monitor (default: `['.dart']`)
  /// - [ignorePatterns]: Patterns to ignore when watching files
  /// - [debounceDelay]: Delay before triggering reload (default: 500ms)
  /// - [verbose]: Enable detailed logging (default: false)
  ///
  /// **Example:**
  /// ```dart
  /// void main() async {
  ///   await DeveloperTools.start(
  ///     script: () async {
  ///       final app = Http(ShelfServer(InternetAddress.anyIPv4, 8080));
  ///       app.get('/').inject('response').action((Response response) {
  ///         response.text('Hello with hot reload!');
  ///         return response;
  ///       });
  ///       await app.start();
  ///     },
  ///     watchPaths: ['lib', 'example'],
  ///     watchExtensions: ['.dart'],
  ///   );
  /// }
  /// ```
  ///
  /// **During development, use:**
  /// - `r` + Enter: Hot reload (preserves state)
  /// - `R` + Enter: Hot restart (full restart)
  /// - `q` + Enter: Quit
  static Future<void> start({
    required Future<void> Function() script,
    List<String> watchPaths = const ['lib'],
    List<String> watchExtensions = const ['.dart'],
    List<String> ignorePatterns = const [
      '.git/',
      '.dart_tool/',
      'build/',
      'pubspec.lock',
    ],
    Duration debounceDelay = const Duration(milliseconds: 500),
    bool verbose = false,
  }) async {
    // Check if this is already the development server process
    if (Platform.environment['UTOPIA_DEV_MODE'] == 'true') {
      // This is the dev server process, just run the user script
      await script();
      return;
    }

    // Check if VM service is enabled, if not, restart with VM service
    await _ensureVmServiceEnabled();

    final config = ReloadConfig(
      mode: ReloadMode.auto, // Always auto mode like Flutter
      watchPaths: watchPaths,
      watchExtensions: watchExtensions,
      ignorePatterns: ignorePatterns,
      debounceDelay: debounceDelay,
      verbose: verbose,
    );

    print('🔥 Hot reload enabled. Press:');
    print('  r + Enter: Hot reload');
    print('  R + Enter: Hot restart');
    print('  q + Enter: Quit');
    print('');

    // Start the development server that manages the user script in a separate process
    final devServer = _DevelopmentServer(config: config);
    await devServer.start();
  }

  /// Ensure VM service is enabled for true hot reload
  static Future<void> _ensureVmServiceEnabled() async {
    try {
      // Try to get service info
      final serviceInfo = await developer.Service.getInfo();
      if (serviceInfo.serverUri != null) {
        // VM service is already enabled
        return;
      }
    } catch (e) {
      // Service not available
    }

    // VM service is not enabled, restart with it enabled
    if (!Platform.executableArguments.any((arg) =>
        arg.startsWith('--enable-vm-service') || arg.startsWith('--observe'))) {
      print('🔄 Restarting with VM service enabled for true hot reload...');

      final scriptPath = Platform.script.toFilePath();
      final args = [
        '--enable-vm-service=0', // Use port 0 for automatic port selection
        '--disable-service-auth-codes',
        ...Platform.executableArguments,
        scriptPath,
      ];

      final process = await Process.start(
        Platform.executable,
        args,
        mode: ProcessStartMode
            .inheritStdio, // inherit terminal IO so stdin/sigint work
      );

      // Forward stdout and stderr
      // With inheritStdio, output is already connected, but keep listeners for safety
      try {
        process.stdout.listen((data) => stdout.add(data));
        process.stderr.listen((data) => stderr.add(data));
      } catch (_) {
        // Ignore if streams are not available in inherit mode
      }

      final exitCode = await process.exitCode;
      exit(exitCode);
    }
  }
}

/// Separate development server process that manages the user script
class _DevelopmentServer {
  final ReloadConfig config;
  Process? _userProcess;
  late final HotReloadFileWatcher _fileWatcher;
  StreamSubscription? _stdinSubscription;
  bool _isReloading = false;
  bool _isRestarting = false;
  bool _isShuttingDown = false;

  // VM service connection to child process for true hot reload
  VmService? _childVmService;
  String? _childIsolateId;
  bool _vmConnected = false;

  _DevelopmentServer({required this.config});

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

    // Set up file watching
    await _setupFileWatcher();

    // Set up background stdin listening (safe in dev server process)
    await _setupStdinListener();

    // Start the user script in a separate process
    await _startUserScript();

    // Keep the dev server alive
    await Completer().future;
  }

  Future<void> _setupFileWatcher() async {
    _fileWatcher = HotReloadFileWatcher(config);

    print('👁️  Setting up file watchers...');
    for (final path in config.watchPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        print('👁️  Watching directory: ${dir.path}');
      }
    }

    await _fileWatcher.start((filePath) {
      final relativePath = _getRelativePath(filePath);
      print('📝 File changed: $relativePath');
      _performAutoReload();
    });

    print('✅ Started ${config.watchPaths.length} file watcher(s)');
  }

  Future<void> _setupStdinListener() async {
    print('🎮 Background keyboard input enabled...');
    print('💡 Press: r (reload), R (restart), q (quit), or Ctrl+C');

    bool rawMode = false;

    // Try raw mode for immediate character detection (enable on all platforms; fallback on error)
    if (stdin.hasTerminal) {
      try {
        stdin.echoMode = false;
        stdin.lineMode = false;
        rawMode = true;
      } catch (e) {
        rawMode = false;
      }
    }

    // Background stdin listener
    if (rawMode) {
      _stdinSubscription = stdin.listen((data) {
        for (final byte in data) {
          final char = String.fromCharCode(byte);
          // Handle Ctrl+C in raw mode (ETX, char code 3)
          if (byte == 3) {
            print('\n🛑 Ctrl+C detected - shutting down...');
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
              print('\n👋 Shutting down...');
              _shutdown();
              return;
          }
        }
      }, onError: (_) {}, cancelOnError: false);
    } else {
      // Fallback to line-based mode
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
            print('👋 Shutting down...');
            _shutdown();
            break;
          default:
            // Also accept lowercase after normalization
            switch (command.toLowerCase()) {
              case 'r':
                print('🔥 Manual hot reload triggered...');
                _performHotReload();
                break;
              case 'q':
              case 'quit':
              case 'exit':
                print('👋 Shutting down...');
                _shutdown();
                break;
            }
        }
      }, onError: (_) {}, cancelOnError: false);
    }

    // Handle Ctrl+C
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n🛑 Ctrl+C detected - shutting down...');
      await _shutdown();
    });

    // Also handle SIGTERM where supported (not on Windows)
    try {
      if (!Platform.isWindows) {
        ProcessSignal.sigterm.watch().listen((_) async {
          print('\n🛑 SIGTERM received - shutting down...');
          await _shutdown();
        });
      }
    } catch (_) {
      // Ignore if the platform doesn't support SIGTERM
    }
  }

  Future<void> _startUserScript() async {
    final scriptPath = Platform.script.toFilePath();
    final args = [
      '--enable-vm-service=0',
      '--disable-service-auth-codes',
      ...Platform.executableArguments,
      scriptPath,
    ];

    final environment = Map<String, String>.from(Platform.environment);
    environment['UTOPIA_DEV_MODE'] = 'true';

    _userProcess = await Process.start(
      Platform.executable,
      args,
      environment: environment,
    );

    // Reset child VM connection state for new child
    _vmConnected = false;
    _childIsolateId = null;
    try {
      await _childVmService?.dispose();
    } catch (_) {}
    _childVmService = null;

    // Forward output from user process and sniff VM service URI
    _userProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln(line);
      _maybeCaptureVmServiceUri(line);
    });
    _userProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderr.writeln(line);
      _maybeCaptureVmServiceUri(line);
    });

    // Wait a bit for the user script to start
    await Future.delayed(Duration(milliseconds: 1000));
    print('✅ User script started');

    // Monitor user process
    _userProcess!.exitCode.then((exitCode) {
      if (!_isReloading && !_isRestarting && !_isShuttingDown) {
        print('❌ User script exited with code $exitCode');
        _shutdown();
      }
    });
  }

  // Parse child's VM service URL from its output and connect
  void _maybeCaptureVmServiceUri(String line) {
    final marker = 'The Dart VM service is listening on ';
    final idx = line.indexOf(marker);
    if (idx == -1) return;
    final uriStr = line.substring(idx + marker.length).trim();
    // Example: http://127.0.0.1:58858/
    _connectToChildVmService(uriStr);
  }

  Future<void> _connectToChildVmService(String httpUri) async {
    if (_vmConnected) return;
    try {
      var wsUri = httpUri.replaceFirst('http', 'ws');
      if (!wsUri.endsWith('/ws')) {
        if (!wsUri.endsWith('/')) wsUri = '$wsUri/';
        wsUri = '${wsUri}ws';
      }
      if (config.verbose) {
        print('🔌 Connecting to child VM service: $wsUri');
      }
      final service = await vmServiceConnectUri(wsUri);
      final vm = await service.getVM();
      if (vm.isolates?.isNotEmpty == true) {
        _childIsolateId = vm.isolates!.first.id!;
        _childVmService = service;
        _vmConnected = true;
        print('✅ Connected to child VM service - hot reload enabled');
      } else {
        await service.dispose();
      }
    } catch (e) {
      if (config.verbose) {
        print('⚠️  Failed to connect to child VM service: $e');
      }
    }
  }

  Future<void> _performAutoReload() async {
    if (_isReloading) return;
    _isReloading = true;

    try {
      // Try hot reload first
      final success = await _performHotReload();
      if (!success) {
        print('🔄 Hot reload failed, performing hot restart...');
        await _performHotRestart();
      }
    } finally {
      _isReloading = false;
    }
  }

  Future<bool> _performHotReload() async {
    try {
      if (!_vmConnected || _childVmService == null || _childIsolateId == null) {
        if (config.verbose) {
          print('ℹ️  Child VM service not connected; cannot hot reload');
        }
        return false;
      }
      print('🔥 Performing hot reload...');
      final report = await _childVmService!.reloadSources(_childIsolateId!);
      if (report.success == true) {
        print('✅ Hot reload completed');
        return true;
      }
      if (config.verbose && report.json != null) {
        print('❌ Hot reload failed: ${report.json}');
      } else {
        print('❌ Hot reload failed');
      }
      return false;
    } catch (e) {
      print('❌ Hot reload failed: $e');
      return false;
    }
  }

  Future<void> _performHotRestart() async {
    try {
      print('🔄 Performing hot restart...');
      _isRestarting = true;
      // Kill current user process
      await _killUserProcess();

      // Start new user process
      await _startUserScript();

      print('✅ Hot restart completed');
    } catch (e) {
      print('❌ Hot restart failed: $e');
    } finally {
      _isRestarting = false;
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
    if (_isShuttingDown) return;
    _isShuttingDown = true;
    print('🛑 Shutting down development server...');

    // Restore terminal settings safely
    if (!Platform.isWindows) {
      try {
        if (stdin.hasTerminal) {
          stdin.echoMode = true;
          stdin.lineMode = true;
        }
      } catch (e) {
        // Ignore terminal restoration errors
      }
    }

    await _stdinSubscription?.cancel();
    await _fileWatcher.stop();

    await _killUserProcess();

    print('✅ Development server stopped');
    exit(0);
  }

  Future<void> _killUserProcess() async {
    if (_userProcess == null) return;
    print('   Stopping user script...');
    if (Platform.isWindows) {
      // Windows: generic kill terminates the process
      _userProcess!.kill();
      try {
        await _userProcess!.exitCode.timeout(Duration(seconds: 2));
      } catch (_) {
        // Already terminated or unreachable
      }
    } else {
      // POSIX: try graceful then force
      try {
        _userProcess!.kill(ProcessSignal.sigterm);
      } catch (_) {
        _userProcess!.kill();
      }
      try {
        await _userProcess!.exitCode.timeout(Duration(seconds: 2));
      } catch (_) {
        try {
          _userProcess!.kill(ProcessSignal.sigkill);
        } catch (_) {
          _userProcess!.kill();
        }
      }
    }
  }
}
