import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'reload_mode.dart';
import 'file_watcher.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Developer tools for hot reload functionality.
///
/// Provides a Flutter-like development experience for any Dart application
/// with automatic hot reload (preserving state) and hot restart (full restart)
/// based on code changes.
///
/// ## Features
///
/// - **Hot Reload**: Uses Dart VM service to reload code while preserving state
/// - **Smart Fallback**: Automatically falls back to hot restart when reload fails
/// - **File Watching**: Monitors specified directories with intelligent debouncing
/// - **Interactive Commands**: Flutter-like keyboard shortcuts (r/R/q)
/// - **Process Isolation**: Runs your app in a separate process for stability
///
/// ## Example Usage
///
/// ```dart
/// import 'package:utopia_hotreload/utopia_hotreload.dart';
///
/// void main() async {
///   await DeveloperTools.start(
///     script: runMyApp,
///     watchPaths: ['lib', 'bin'],
///     watchExtensions: ['.dart', '.yaml'],
///   );
/// }
///
/// Future<void> runMyApp() async {
///   print('App is running with hot reload!');
/// }
/// ```
class DeveloperTools {
  DeveloperTools._();

  /// Starts a development server with hot reload capabilities.
  ///
  /// Sets up file watching, process management, and interactive commands
  /// to provide a seamless development experience.
  ///
  /// ## Parameters
  ///
  /// - **[script]**: The main function of your application. Executed in a
  ///   separate process and can be hot reloaded or restarted.
  ///
  /// - **[watchPaths]**: List of directory paths to monitor for changes.
  ///   Defaults to `['lib']`. Use relative paths from your project root.
  ///
  /// - **[watchExtensions]**: File extensions to watch for changes.
  ///   Defaults to `['.dart']`. Include the dot (e.g., '.dart', '.yaml').
  ///
  /// - **[ignorePatterns]**: Patterns to ignore when watching files.
  ///   Useful for excluding build directories, version control, etc.
  ///
  /// - **[debounceDelay]**: Time to wait after a file change before triggering
  ///   a reload. Prevents excessive reloads during rapid saves. Defaults to 500ms.
  ///
  /// - **[verbose]**: Enable detailed logging for debugging. Shows file events,
  ///   VM service details, and diagnostic information. Defaults to false.
  ///
  /// - **[childVmServicePort]**: Specific port for the child VM service.
  ///   If null, uses an available port automatically.
  ///
  /// ## Interactive Commands
  ///
  /// While running, use these commands:
  ///
  /// - **`r`** + Enter: Hot reload (preserves application state)
  /// - **`R`** + Enter: Hot restart (full application restart)
  /// - **`q`** + Enter: Quit the development server
  /// - **Ctrl+C**: Force quit the development server
  ///
  /// ## Examples
  ///
  /// ### Basic Usage
  /// ```dart
  /// await DeveloperTools.start(
  ///   script: () async {
  ///     print('Hello, hot reload!');
  ///   },
  /// );
  /// ```
  ///
  /// ### HTTP Server Example
  /// ```dart
  /// await DeveloperTools.start(
  ///   script: () async {
  ///     final server = await HttpServer.bind('localhost', 8080);
  ///     await for (final request in server) {
  ///       request.response
  ///         ..write('Hello from hot reload! ${DateTime.now()}')
  ///         ..close();
  ///     }
  ///   },
  ///   watchPaths: ['lib', 'web'],
  ///   verbose: true,
  /// );
  /// ```
  ///
  /// ### Custom Configuration
  /// ```dart
  /// await DeveloperTools.start(
  ///   script: runMyComplexApp,
  ///   watchPaths: ['lib', 'bin', 'config'],
  ///   watchExtensions: ['.dart', '.yaml', '.json'],
  ///   ignorePatterns: ['.git/', 'build/', 'temp/'],
  ///   debounceDelay: Duration(milliseconds: 200),
  ///   verbose: false,
  /// );
  /// ```
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
    int? childVmServicePort,
  }) async {
    if (Platform.environment['UTOPIA_DEV_MODE'] == 'true') {
      await script();
      return;
    }

    await _ensureVmServiceEnabled();

    final config = ReloadConfig(
      mode: ReloadMode.auto,
      watchPaths: watchPaths,
      watchExtensions: watchExtensions,
      ignorePatterns: ignorePatterns,
      debounceDelay: debounceDelay,
      verbose: verbose,
      childVmServicePort: childVmServicePort,
    );

    print('🔥 Hot reload enabled. Press:');
    print('  r + Enter: Hot reload');
    print('  R + Enter: Hot restart');
    print('  q + Enter: Quit');
    print('');

    final devServer = _DevelopmentServer(config: config);
    await devServer.start();
  }

  /// Ensures VM service is enabled for hot reload functionality.
  static Future<void> _ensureVmServiceEnabled() async {
    try {
      final serviceInfo = await developer.Service.getInfo();
      if (serviceInfo.serverUri != null) {
        return;
      }
    } catch (e) {
      // Service not available
    }

    if (!Platform.executableArguments.any((arg) =>
        arg.startsWith('--enable-vm-service') || arg.startsWith('--observe'))) {
      print('🔄 Restarting with VM service enabled for true hot reload...');

      final scriptPath = Platform.script.toFilePath();
      final args = [
        '--enable-vm-service=0',
        '--disable-service-auth-codes',
        ...Platform.executableArguments,
        scriptPath,
      ];

      final process = await Process.start(
        Platform.executable,
        args,
        mode: ProcessStartMode.inheritStdio,
      );

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

/// Development server that manages the user script in a separate process.
class _DevelopmentServer {
  final ReloadConfig config;
  Process? _userProcess;
  late final HotReloadFileWatcher _fileWatcher;
  StreamSubscription? _stdinSubscription;
  bool _isReloading = false;
  bool _isRestarting = false;
  bool _isShuttingDown = false;

  VmService? _childVmService;
  String? _childIsolateId;
  bool _vmConnected = false;
  int? _childVmPort;

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

    await _setupFileWatcher();
    await _setupStdinListener();
    await _startUserScript();

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

    if (stdin.hasTerminal) {
      try {
        stdin.echoMode = false;
        stdin.lineMode = false;
        rawMode = true;
      } catch (e) {
        rawMode = false;
      }
    }

    if (rawMode) {
      _stdinSubscription = stdin.listen((data) {
        for (final byte in data) {
          final char = String.fromCharCode(byte);
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

    ProcessSignal.sigint.watch().listen((_) async {
      print('\n🛑 Ctrl+C detected - shutting down...');
      await _shutdown();
    });

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

    final parentArgs = Platform.executableArguments.where((arg) {
      return !(arg.startsWith('--enable-vm-service') ||
          arg.startsWith('--observe') ||
          arg.startsWith('--disable-service-auth-codes'));
    }).toList();

    final vmPort = _childVmPort ?? config.childVmServicePort ?? 0;
    final args = [
      '--enable-vm-service=$vmPort',
      '--disable-service-auth-codes',
      ...parentArgs,
      scriptPath,
    ];

    final environment = Map<String, String>.from(Platform.environment);
    environment['UTOPIA_DEV_MODE'] = 'true';

    _userProcess = await Process.start(
      Platform.executable,
      args,
      environment: environment,
    );

    _vmConnected = false;
    _childIsolateId = null;
    try {
      await _childVmService?.dispose();
    } catch (_) {}
    _childVmService = null;

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

    await Future.delayed(Duration(milliseconds: 1000));
    print('✅ User script started');

    _userProcess!.exitCode.then((exitCode) {
      if (!_isReloading && !_isRestarting && !_isShuttingDown) {
        print('❌ User script exited with code $exitCode');
        _shutdown();
      }
    });
  }

  void _maybeCaptureVmServiceUri(String line) {
    final marker = 'The Dart VM service is listening on ';
    final idx = line.indexOf(marker);
    if (idx == -1) return;
    final uriStr = line.substring(idx + marker.length).trim();
    _connectToChildVmService(uriStr);
    try {
      final uri = Uri.parse(uriStr);
      if (uri.hasPort && uri.port > 0) {
        _childVmPort = uri.port;
      }
    } catch (_) {}
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
      await _killUserProcess();
      await Future.delayed(Duration(milliseconds: 150));
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
      _userProcess!.kill();
      try {
        await _userProcess!.exitCode.timeout(Duration(seconds: 2));
      } catch (_) {
        // Already terminated or unreachable
      }
    } else {
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
