import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'reload_config.dart';
import 'file_watcher.dart';
import 'service_config.dart';
import 'multi_service_manager.dart';
import 'keyboard_input_handler.dart';
import 'file_pattern_matcher.dart';
import 'dashboard/dashboard_service.dart';
import 'lifecycle_hooks.dart';
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
  ///
  /// ### Advanced Pattern Matching
  /// ```dart
  /// await DeveloperTools.start(
  ///   script: runMyApp,
  ///   watchPaths: ['lib', 'web'],
  ///   patternPresets: ['dart-project', 'web-project'],
  ///   customPatterns: [
  ///     FilePattern.include('**/*.env'),
  ///     FilePattern.exclude('lib/generated/**'),
  ///   ],
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
    List<String> patternPresets = const [],
    List<FilePattern> customPatterns = const [],
    FilePatternMatcher? patternMatcher,
    Duration debounceDelay = const Duration(milliseconds: 500),
    bool verbose = false,
    int? childVmServicePort,
    bool enableDashboard = false,
    int dashboardPort = 9000,
    LifecycleHooks? hooks,
  }) async {
    if (Platform.environment['UTOPIA_DEV_MODE'] == 'true') {
      await script();
      return;
    }

    await _ensureVmServiceEnabled();

    // Create configuration based on what's provided
    late final ReloadConfig config;

    if (patternMatcher != null) {
      config = ReloadConfig.withMatcher(
        mode: ReloadMode.auto,
        watchPaths: watchPaths,
        patternMatcher: patternMatcher,
        debounceDelay: debounceDelay,
        verbose: verbose,
        childVmServicePort: childVmServicePort,
        enableDashboard: enableDashboard,
        dashboardPort: dashboardPort,
      );
    } else if (patternPresets.isNotEmpty || customPatterns.isNotEmpty) {
      config = ReloadConfig.withPatterns(
        mode: ReloadMode.auto,
        watchPaths: watchPaths,
        presets: patternPresets,
        patterns: customPatterns,
        debounceDelay: debounceDelay,
        verbose: verbose,
        childVmServicePort: childVmServicePort,
        enableDashboard: enableDashboard,
        dashboardPort: dashboardPort,
      );
    } else {
      config = ReloadConfig(
        mode: ReloadMode.auto,
        watchPaths: watchPaths,
        watchExtensions: watchExtensions,
        ignorePatterns: ignorePatterns,
        debounceDelay: debounceDelay,
        verbose: verbose,
        childVmServicePort: childVmServicePort,
        enableDashboard: enableDashboard,
        dashboardPort: dashboardPort,
      );
    }

    print('🔥 Hot reload enabled. Press:');
    print('  r: Hot reload');
    print('  R: Hot restart');
    print('  q: Quit');
    print('');

    final devServer = _DevelopmentServer(config: config, hooks: hooks);
    await devServer.start();
  }

  /// Starts multiple services in a coordinated development environment.
  ///
  /// Allows running multiple scripts/services simultaneously, each with their own
  /// configuration and reload behavior, while providing unified control and monitoring.
  ///
  /// ## Parameters
  ///
  /// - **[services]**: List of service configurations to start. Each service can
  ///   have its own watch paths, extensions, and script.
  ///
  /// - **[globalWatchPaths]**: Default watch paths used by services that don't
  ///   specify their own. Defaults to `['lib']`.
  ///
  /// - **[globalWatchExtensions]**: Default file extensions used by services that
  ///   don't specify their own. Defaults to `['.dart']`.
  ///
  /// - **[globalIgnorePatterns]**: Default ignore patterns used by services that
  ///   don't specify their own.
  ///
  /// - **[debounceDelay]**: Global debounce delay for file changes. Defaults to 500ms.
  ///
  /// - **[verbose]**: Enable detailed logging for all services. Defaults to false.
  ///
  /// ## Example
  ///
  /// ```dart
  /// await DeveloperTools.startMultiple([
  ///   ServiceConfig(
  ///     name: 'api-server',
  ///     script: runApiServer,
  ///     watchPaths: ['lib/api', 'lib/shared'],
  ///     displayName: 'API Server',
  ///   ),
  ///   ServiceConfig(
  ///     name: 'web-server',
  ///     script: runWebServer,
  ///     watchPaths: ['web', 'lib/web'],
  ///     watchExtensions: ['.dart', '.html', '.css'],
  ///     displayName: 'Web Server',
  ///   ),
  /// ]);
  /// ```
  ///
  /// ## Advanced Pattern Matching
  /// ```dart
  /// await DeveloperTools.startMultiple([
  ///   ServiceConfig.withPatterns(
  ///     name: 'api',
  ///     script: runApi,
  ///     presets: ['dart-project'],
  ///   ),
  ///   ServiceConfig.withPatterns(
  ///     name: 'web',
  ///     script: runWeb,
  ///     presets: ['web-project'],
  ///   ),
  /// ],
  /// globalPatternPresets: ['dart-project'],
  /// globalCustomPatterns: [FilePattern.exclude('**/*.log')],
  /// );
  /// ```
  ///
  /// ## Interactive Commands
  ///
  /// While running, use these commands:
  ///
  /// - **`r`** + Enter: Hot reload all services
  /// - **`R`** + Enter: Hot restart all services
  /// - **`l`** + Enter: List service status
  /// - **`s`** + Enter: Stop a service
  /// - **`t`** + Enter: Start a service
  /// - **`q`** + Enter: Quit all services
  /// - **Ctrl+C**: Force quit all services
  static Future<void> startMultiple(
    List<ServiceConfig> services, {
    List<String> globalWatchPaths = const ['lib'],
    List<String> globalWatchExtensions = const ['.dart'],
    List<String> globalIgnorePatterns = const [
      '.git/',
      '.dart_tool/',
      'build/',
      'pubspec.lock',
    ],
    List<String> globalPatternPresets = const [],
    List<FilePattern> globalCustomPatterns = const [],
    FilePatternMatcher? globalPatternMatcher,
    Duration debounceDelay = const Duration(milliseconds: 500),
    bool verbose = false,
    bool interactive = true,
    bool enableDashboard = true,
    String dashboardHost = 'localhost',
    int dashboardPort = 9000,
    // Multi-service lifecycle hooks will be supported in a future version.
    LifecycleHooks? globalHooks,
  }) async {
    if (services.isEmpty) {
      throw ArgumentError('At least one service must be provided');
    }

    final targetServiceName = Platform.environment['UTOPIA_SERVICE_NAME'];
    if (targetServiceName != null) {
      final service = services.firstWhere(
        (s) => s.name == targetServiceName,
        orElse: () => throw ArgumentError(
          'Service not found: $targetServiceName',
        ),
      );
      await service.script();
      return;
    }

    await _ensureVmServiceEnabled();

    if (globalHooks != null) {
      print('⚠️  globalHooks is not yet supported for startMultiple() and will be ignored');
    }

    // Create global configuration based on what's provided
    late final ReloadConfig globalConfig;

    if (globalPatternMatcher != null) {
      globalConfig = ReloadConfig.withMatcher(
        mode: ReloadMode.auto,
        watchPaths: globalWatchPaths,
        patternMatcher: globalPatternMatcher,
        debounceDelay: debounceDelay,
        verbose: verbose,
      );
    } else if (globalPatternPresets.isNotEmpty ||
        globalCustomPatterns.isNotEmpty) {
      globalConfig = ReloadConfig.withPatterns(
        mode: ReloadMode.auto,
        watchPaths: globalWatchPaths,
        presets: globalPatternPresets,
        patterns: globalCustomPatterns,
        debounceDelay: debounceDelay,
        verbose: verbose,
      );
    } else {
      globalConfig = ReloadConfig(
        mode: ReloadMode.auto,
        watchPaths: globalWatchPaths,
        watchExtensions: globalWatchExtensions,
        ignorePatterns: globalIgnorePatterns,
        debounceDelay: debounceDelay,
        verbose: verbose,
      );
    }

    final manager = MultiServiceManager(services, globalConfig);

    // Start dashboard service if enabled
    DashboardService? dashboard;
    if (enableDashboard) {
      dashboard = DashboardService(
        host: dashboardHost,
        port: dashboardPort,
        enabled: true,
      );

      try {
        await dashboard.start();
        dashboard.attachServiceManager(manager);
        manager.attachDashboard(dashboard);
        print(
            '📊 Dashboard available at: http://$dashboardHost:$dashboardPort');
      } catch (e) {
        print('⚠️  Failed to start dashboard: $e');
        dashboard = null; // Don't use dashboard if it failed to start
      }
    }

    await manager.startAll(interactive: interactive);
  }

  /// Ensures VM service is enabled for hot reload functionality.
  static Future<void> _ensureVmServiceEnabled() async {
    // Check if VM service is already enabled via command line arguments
    if (Platform.executableArguments.any((arg) =>
        arg.startsWith('--enable-vm-service') || arg.startsWith('--observe'))) {
      return;
    }

    // Try to check if VM service is available
    try {
      final serviceInfo = await developer.Service.getInfo()
          .timeout(Duration(milliseconds: 500));
      if (serviceInfo.serverUri != null) {
        return;
      }
    } catch (e) {
      // Service not available or timeout - continue with restart
    }

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

/// Development server that manages the user script in a separate process.
class _DevelopmentServer {
  final ReloadConfig config;
  final LifecycleHooks? hooks;
  Process? _userProcess;
  late final HotReloadFileWatcher _fileWatcher;
  StreamSubscription? _stdinSubscription;
  KeyboardInputHandler? _keyboardHandler;
  bool _isReloading = false;
  bool _isRestarting = false;
  bool _isShuttingDown = false;

  VmService? _childVmService;
  String? _childIsolateId;
  bool _vmConnected = false;
  int? _childVmPort;

  // Dashboard support
  DashboardService? _dashboard;

  _DevelopmentServer({required this.config, this.hooks});

  Future<void> start() async {
    print('🚀 Starting application with auto hot reload...');
    print('📁 Watching paths: ${config.watchPaths}');
    print('📄 Watching extensions: ${config.watchExtensions}');
    print('');

    await _setupFileWatcher();

    // Setup dashboard if enabled (after file watcher is ready)
    if (config.enableDashboard) {
      await _setupDashboard();
    }

    print('💡 Commands available:');
    print('  r: Hot reload (preserves state)');
    print('  R: Hot restart (full restart)');
    print('  q: Quit');
    if (config.enableDashboard) {
      print('  📊 Dashboard: http://localhost:${config.dashboardPort}');
    }
    print('');

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

    await _fileWatcher.start((filePath) async {
      final relativePath = _getRelativePath(filePath);
      try {
        await hooks?.onFileChanged?.call(relativePath);
      } catch (e) {
        print('⚠️  onFileChanged hook error: $e');
      }
      _performAutoReload();
    });

    print('✅ Started ${config.watchPaths.length} file watcher(s)');
  }

  Future<void> _setupDashboard() async {
    try {
      _dashboard = DashboardService(
        host: 'localhost',
        port: config.dashboardPort,
      );

      // Attach the file watcher to the dashboard
      _dashboard!.attachFileWatcher(_fileWatcher);

      await _dashboard!.start();
      print(
          '📊 Dashboard started at: http://localhost:${config.dashboardPort}');
    } catch (e) {
      print('⚠️  Failed to start dashboard: $e');
      _dashboard = null;
    }
  }

  Future<void> _setupStdinListener() async {
    _keyboardHandler = KeyboardInputHandler(
      onCtrlC: () => _shutdown(),
      onShutdown: () => _shutdown(),
    );

    // Register command handlers
    _keyboardHandler!.registerCommand('r', () {
      print('🔥 Manual hot reload triggered...');
      _performHotReload();
    });

    _keyboardHandler!.registerCommand('R', () {
      print('🔄 Manual hot restart triggered...');
      _performHotRestart();
    });

    _keyboardHandler!.registerCommand('q', () {
      print('👋 Shutting down...');
      _shutdown();
    });

    _keyboardHandler!.registerCommand('Q', () {
      print('👋 Shutting down...');
      _shutdown();
    });

    // Also register lowercase variants for compatibility
    _keyboardHandler!.registerCommand('quit', () {
      print('👋 Shutting down...');
      _shutdown();
    });

    _keyboardHandler!.registerCommand('exit', () {
      print('� Shutting down...');
      _shutdown();
    });

    // Start listening with help text
    const helpText = '''🎮 Background keyboard input enabled...
💡 Press: r (reload), R (restart), q (quit), or Ctrl+C''';

    await _keyboardHandler!.start(helpText: helpText);
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

    // Safe VM service cleanup to prevent SendPort errors
    if (_childVmService != null) {
      try {
        final service = _childVmService;
        _childVmService = null;
        await service?.dispose();
      } catch (e) {
        // Ignore cleanup errors that can cause SendPort issues
        if (config.verbose) {
          print('⚠️  VM service cleanup warning: $e');
        }
      }
    }

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
        // Safe disposal to prevent SendPort errors
        try {
          await service.dispose();
        } catch (e) {
          if (config.verbose) {
            print('⚠️  VM service disposal warning: $e');
          }
        }
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
        _dashboard?.recordReloadEvent(
          serviceName: 'main',
          type: 'failed',
          duration: Duration.zero,
          error: 'VM service not connected',
        );
        return false;
      }
      print('🔥 Performing hot reload...');
      bool shouldReload = true;
      try {
        shouldReload = await hooks?.onBeforeReload?.call() ?? true;
      } catch (e) {
        print('⚠️  onBeforeReload hook error: $e');
      }
      if (!shouldReload) {
        print('ℹ️  Reload cancelled by onBeforeReload hook');
        return true;
      }
      final stopwatch = Stopwatch()..start();
      final report = await _childVmService!.reloadSources(_childIsolateId!);
      stopwatch.stop();

      if (report.success == true) {
        print('✅ Hot reload completed');
        _dashboard?.recordReloadEvent(
          serviceName: 'main',
          type: 'hot_reload',
          duration: Duration(milliseconds: stopwatch.elapsedMilliseconds),
        );
        try {
          await hooks?.onAfterReload?.call();
        } catch (e) {
          print('⚠️  onAfterReload hook error: $e');
        }
        return true;
      }

      final errorMessage = config.verbose && report.json != null
          ? 'Hot reload failed: ${report.json}'
          : 'Hot reload failed';
      print('❌ $errorMessage');
      _dashboard?.recordReloadEvent(
        serviceName: 'main',
        type: 'failed',
        duration: Duration(milliseconds: stopwatch.elapsedMilliseconds),
        error: errorMessage,
      );
      try {
        await hooks?.onError?.call(errorMessage);
      } catch (e) {
        print('⚠️  onError hook error: $e');
      }
      return false;
    } catch (e) {
      final errorMsg = 'Hot reload failed: $e';
      print('❌ $errorMsg');
      _dashboard?.recordReloadEvent(
        serviceName: 'main',
        type: 'failed',
        duration: Duration.zero,
        error: errorMsg,
      );
      try {
        await hooks?.onError?.call(errorMsg);
      } catch (hookError) {
        print('⚠️  onError hook error: $hookError');
      }
      return false;
    }
  }

  Future<void> _performHotRestart() async {
    try {
      print('🔄 Performing hot restart...');
      _isRestarting = true;
      try {
        await hooks?.onBeforeRestart?.call();
      } catch (e) {
        print('⚠️  onBeforeRestart hook error: $e');
      }
      final stopwatch = Stopwatch()..start();
      await _killUserProcess();
      await Future.delayed(Duration(milliseconds: 150));
      await _startUserScript();
      try {
        await hooks?.onAfterRestart?.call();
      } catch (e) {
        print('⚠️  onAfterRestart hook error: $e');
      }
      stopwatch.stop();
      print('✅ Hot restart completed');
      _dashboard?.recordReloadEvent(
        serviceName: 'main',
        type: 'hot_restart',
        duration: Duration(milliseconds: stopwatch.elapsedMilliseconds),
      );
    } catch (e) {
      final errorMsg = 'Hot restart failed: $e';
      print('❌ $errorMsg');
      try {
        await hooks?.onError?.call(errorMsg);
      } catch (hookError) {
        print('⚠️  onError hook error: $hookError');
      }
      _dashboard?.recordReloadEvent(
        serviceName: 'main',
        type: 'failed',
        duration: Duration.zero,
        error: errorMsg,
      );
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
    print('[STOP] Shutting down development server...');

    // Mark keyboard handler as shutting down to prevent Windows VM crashes
    KeyboardInputHandler.markShuttingDown();

    // Stop keyboard input handler (handles terminal restoration)
    await _keyboardHandler?.stop();

    await _stdinSubscription?.cancel();
    await _fileWatcher.stop();

    // Stop dashboard if running
    await _dashboard?.stop();

    await _killUserProcess();

    print('Development server stopped');
    exit(0);
  }

  Future<void> _killUserProcess() async {
    if (_userProcess == null) return;
    print('   Stopping user script...');

    // Clean up VM service connection before terminating process
    if (_childVmService != null) {
      try {
        final service = _childVmService;
        _childVmService = null;
        _vmConnected = false;
        _childIsolateId = null;
        await service?.dispose();
      } catch (e) {
        // Ignore VM service cleanup errors during shutdown
      }
    }

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
