import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:utopia_hotreload/utopia_hotreload.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:watcher/watcher.dart';

const String version = '2.0.0';

void main(List<String> args) async {
  // Parse arguments
  final config = _parseArgs(args);
  if (config == null) return; // --help or --version was shown

  final verbose = config.verbose;
  final scriptPath = config.scriptPath;

  // Verify the script exists
  if (!File(scriptPath).existsSync()) {
    stderr.writeln('Error: Script not found: $scriptPath');
    exit(1);
  }

  // Try loading hotreload.yaml for defaults
  ReloadConfig? fileConfig;
  try {
    fileConfig = ReloadConfigFile.load();
    if (fileConfig != null && verbose) {
      print('📄 Loaded configuration from hotreload.yaml');
    }
  } catch (e) {
    if (verbose) {
      print('⚠️  Failed to load hotreload.yaml: $e');
    }
  }

  // Apply config file as fallback defaults for unspecified CLI args
  final watchPaths = config.watchExplicit
      ? config.watchPaths
      : (config.watchPaths.isNotEmpty
          ? config.watchPaths
          : (fileConfig?.watchPaths ?? ['lib']));
  final watchExtensions = config.extExplicit
      ? config.watchExtensions
      : (config.watchExtensions.isNotEmpty
          ? config.watchExtensions
          : (fileConfig?.watchExtensions ?? ['.dart']));
  final debounceMs = config.debounceExplicit
      ? config.debounceMs
      : (fileConfig?.debounceDelay.inMilliseconds ?? config.debounceMs);
  final resolvedVerbose = config.verboseExplicit
      ? config.verbose
      : (fileConfig?.verbose ?? config.verbose);

  final resolvedConfig = _CliConfig(
    scriptPath: scriptPath,
    scriptArgs: config.scriptArgs,
    watchPaths: watchPaths.isEmpty ? ['lib'] : watchPaths,
    watchExtensions: watchExtensions.isEmpty ? ['.dart'] : watchExtensions,
    debounceMs: debounceMs,
    verbose: resolvedVerbose,
  );

  print('🔥 utopia_hotreload v$version');
  print('📄 Script: $scriptPath');
  print('📁 Watching: ${resolvedConfig.watchPaths}');
  print('📄 Extensions: ${resolvedConfig.watchExtensions}');
  print('');
  print('💡 Commands:');
  print('  r: Hot reload (falls back to restart if needed)');
  print('  q: Quit');
  print('');

  final runner = _ScriptRunner(config: resolvedConfig);
  await runner.start();
}

class _CliConfig {
  final String scriptPath;
  final List<String> scriptArgs;
  final List<String> watchPaths;
  final List<String> watchExtensions;
  final int debounceMs;
  final bool verbose;
  final bool watchExplicit;
  final bool extExplicit;
  final bool debounceExplicit;
  final bool verboseExplicit;

  _CliConfig({
    required this.scriptPath,
    required this.scriptArgs,
    required this.watchPaths,
    required this.watchExtensions,
    required this.debounceMs,
    required this.verbose,
    this.watchExplicit = false,
    this.extExplicit = false,
    this.debounceExplicit = false,
    this.verboseExplicit = false,
  });
}

_CliConfig? _parseArgs(List<String> args) {
  final watchPaths = <String>[];
  final watchExtensions = <String>[];
  int debounceMs = 500;
  bool verbose = false;
  bool watchExplicit = false;
  bool extExplicit = false;
  bool debounceExplicit = false;
  bool verboseExplicit = false;
  String? scriptPath;
  final scriptArgs = <String>[];

  int i = 0;
  bool pastSeparator = false;

  while (i < args.length) {
    final arg = args[i];

    if (pastSeparator) {
      scriptArgs.add(arg);
      i++;
      continue;
    }

    if (arg == '--') {
      pastSeparator = true;
      i++;
      continue;
    }

    if (arg == '--help' || arg == '-h') {
      _printUsage();
      return null;
    }

    if (arg == '--version') {
      print('utopia_hotreload v$version');
      return null;
    }

    if (arg == '--verbose' || arg == '-v') {
      verbose = true;
      verboseExplicit = true;
      i++;
      continue;
    }

    if (arg == '--watch' || arg == '-w') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: --watch requires a path argument');
        exit(1);
      }
      watchPaths.add(args[i + 1]);
      watchExplicit = true;
      i += 2;
      continue;
    }

    if (arg == '--ext' || arg == '-e') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: --ext requires an extensions argument');
        exit(1);
      }
      for (final ext in args[i + 1].split(',')) {
        final trimmed = ext.trim();
        if (trimmed.isNotEmpty) {
          watchExtensions.add(trimmed.startsWith('.') ? trimmed : '.$trimmed');
        }
      }
      extExplicit = true;
      i += 2;
      continue;
    }

    if (arg == '--debounce') {
      if (i + 1 >= args.length) {
        stderr.writeln('Error: --debounce requires a milliseconds argument');
        exit(1);
      }
      final parsed = int.tryParse(args[i + 1]);
      if (parsed == null || parsed <= 0) {
        stderr.writeln('Error: --debounce must be a positive integer (got: ${args[i + 1]})');
        exit(1);
      }
      debounceMs = parsed;
      debounceExplicit = true;
      i += 2;
      continue;
    }

    if (arg.startsWith('-')) {
      stderr.writeln('Error: Unknown option: $arg');
      stderr.writeln('Run with --help for usage information.');
      exit(1);
    }

    // First non-option argument is the script path
    scriptPath = arg;
    i++;
    // Everything after the script path is passed to the script
    while (i < args.length) {
      if (args[i] == '--') {
        i++;
        continue;
      }
      scriptArgs.add(args[i]);
      i++;
    }
    break;
  }

  if (scriptPath == null) {
    stderr.writeln('Error: No script specified.');
    stderr.writeln('');
    _printUsage();
    exit(1);
  }

  return _CliConfig(
    scriptPath: scriptPath,
    scriptArgs: scriptArgs,
    watchPaths: watchPaths,
    watchExtensions: watchExtensions,
    debounceMs: debounceMs,
    verbose: verbose,
    watchExplicit: watchExplicit,
    extExplicit: extExplicit,
    debounceExplicit: debounceExplicit,
    verboseExplicit: verboseExplicit,
  );
}

void _printUsage() {
  print('''
utopia_hotreload v$version - Hot reload for any Dart script

Usage: dart run utopia_hotreload [options] <script.dart> [-- script-args...]

Options:
  --watch, -w <path>       Directory to watch (repeatable, default: lib)
  --ext, -e <extensions>   File extensions to watch (comma-separated, default: .dart)
  --debounce <ms>          Debounce delay in milliseconds (default: 500)
  --verbose, -v            Enable verbose logging
  --help, -h               Show this help message
  --version                Show version

Examples:
  dart run utopia_hotreload bin/server.dart
  dart run utopia_hotreload -w lib -w bin bin/server.dart
  dart run utopia_hotreload -e .dart,.yaml --verbose bin/server.dart
  dart run utopia_hotreload bin/server.dart --port 8080''');
}

class _ScriptRunner {
  final _CliConfig config;
  Process? _childProcess;
  VmService? _vmService;
  String? _isolateId;
  bool _vmConnected = false;
  int? _lastVmPort;

  bool _isReloading = false;
  bool _isRestarting = false;
  bool _isShuttingDown = false;

  KeyboardInputHandler? _keyboardHandler;
  final List<StreamSubscription> _fileWatchers = [];
  Timer? _debounceTimer;

  _ScriptRunner({required this.config});

  Future<void> start() async {
    await _setupFileWatching();
    await _setupKeyboardInput();
    await _startScript();

    // Keep running
    await Completer<void>().future;
  }

  Future<void> _setupFileWatching() async {
    for (final watchPath in config.watchPaths) {
      final dir = Directory(watchPath);
      if (!dir.existsSync()) {
        print('⚠️  Watch path does not exist: $watchPath');
        continue;
      }

      print('👁️  Watching: ${dir.absolute.path}');
      final watcher = DirectoryWatcher(dir.absolute.path);
      final sub = watcher.events.listen((event) {
        final filePath = event.path;
        final ext = p.extension(filePath);

        if (!config.watchExtensions.contains(ext)) return;

        if (config.verbose) {
          print('📁 File event: ${event.type} - $filePath');
        }

        _debounceTimer?.cancel();
        _debounceTimer = Timer(
          Duration(milliseconds: config.debounceMs),
          () {
            print('📝 File changed: ${p.relative(filePath)}');
            _performAutoReload();
          },
        );
      });
      _fileWatchers.add(sub);
    }

    if (_fileWatchers.isEmpty) {
      stderr.writeln('Error: No valid watch paths found.');
      exit(1);
    }
    print('✅ File watchers started');
  }

  Future<void> _setupKeyboardInput() async {
    _keyboardHandler = KeyboardInputHandler(
      onCtrlC: () => _shutdown(),
      onShutdown: () => _shutdown(),
    );

    _keyboardHandler!.registerCommand('r', () {
      print('🔥 Reload triggered...');
      _performAutoReload();
    });

    _keyboardHandler!.registerCommand('q', () {
      print('👋 Shutting down...');
      _shutdown();
    });

    await _keyboardHandler!.start(
      helpText:
          '🎮 Press: r (hot reload with restart fallback), q (quit), Ctrl+C (force quit)',
    );
  }

  Future<void> _startScript() async {
    final resolvedPath = p.absolute(config.scriptPath);

    final vmPort = _lastVmPort ?? 0;
    final processArgs = [
      '--enable-vm-service=$vmPort',
      '--disable-service-auth-codes',
      resolvedPath,
      ...config.scriptArgs,
    ];

    if (config.verbose) {
      print('🚀 Starting: ${Platform.executable} ${processArgs.join(' ')}');
    }

    _childProcess = await Process.start(
      Platform.executable,
      processArgs,
    );

    _vmConnected = false;
    _isolateId = null;

    if (_vmService != null) {
      try {
        final service = _vmService;
        _vmService = null;
        await service?.dispose();
      } catch (_) {}
    }

    _childProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln(line);
      _captureVmServiceUri(line);
    });

    _childProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderr.writeln(line);
      _captureVmServiceUri(line);
    });

    _childProcess!.exitCode.then((exitCode) {
      if (!_isReloading && !_isRestarting && !_isShuttingDown) {
        print('❌ Script exited with code $exitCode');
        _shutdown();
      }
    });

    print('🚀 Script started (PID: ${_childProcess!.pid})');
  }

  void _captureVmServiceUri(String line) {
    const marker = 'The Dart VM service is listening on ';
    final idx = line.indexOf(marker);
    if (idx == -1) return;
    final uriStr = line.substring(idx + marker.length).trim();
    _connectToVmService(uriStr);
    try {
      final uri = Uri.parse(uriStr);
      if (uri.hasPort && uri.port > 0) {
        _lastVmPort = uri.port;
      }
    } catch (_) {}
  }

  Future<void> _connectToVmService(String httpUri) async {
    if (_vmConnected) return;
    try {
      var wsUri = httpUri.replaceFirst('http', 'ws');
      if (!wsUri.endsWith('/ws')) {
        if (!wsUri.endsWith('/')) wsUri = '$wsUri/';
        wsUri = '${wsUri}ws';
      }
      if (config.verbose) {
        print('🔌 Connecting to VM service: $wsUri');
      }
      final service = await vmServiceConnectUri(wsUri);
      final vm = await service.getVM();
      if (vm.isolates?.isNotEmpty == true) {
        _isolateId = vm.isolates!.first.id!;
        _vmService = service;
        _vmConnected = true;
        print('✅ VM service connected - hot reload ready');
      } else {
        try {
          await service.dispose();
        } catch (_) {}
      }
    } catch (e) {
      if (config.verbose) {
        print('⚠️  Failed to connect to VM service: $e');
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
    if (!_vmConnected || _vmService == null || _isolateId == null) {
      if (config.verbose) {
        print('ℹ️  VM service not connected; cannot hot reload');
      }
      return false;
    }
    try {
      print('🔥 Performing hot reload...');
      final stopwatch = Stopwatch()..start();
      final report = await _vmService!.reloadSources(_isolateId!);
      stopwatch.stop();
      if (report.success == true) {
        print('✅ Hot reload completed in ${stopwatch.elapsedMilliseconds}ms');
        return true;
      }
      final errorMessage = config.verbose && report.json != null
          ? 'Hot reload failed: ${report.json}'
          : 'Hot reload failed';
      print('❌ $errorMessage');
      return false;
    } catch (e) {
      print('❌ Hot reload error: $e');
      return false;
    }
  }

  Future<void> _performHotRestart() async {
    if (_isRestarting) return;
    _isRestarting = true;
    try {
      print('🔄 Performing hot restart...');
      await _killChild();
      await Future.delayed(const Duration(milliseconds: 150));
      await _startScript();
      print('✅ Hot restart completed');
    } catch (e) {
      print('❌ Hot restart failed: $e');
    } finally {
      _isRestarting = false;
    }
  }

  Future<void> _killChild() async {
    if (_childProcess == null) return;

    if (_vmService != null) {
      try {
        final service = _vmService;
        _vmService = null;
        _vmConnected = false;
        _isolateId = null;
        await service?.dispose();
      } catch (_) {}
    }

    if (Platform.isWindows) {
      _childProcess!.kill();
      try {
        await _childProcess!.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}
    } else {
      try {
        _childProcess!.kill(ProcessSignal.sigterm);
      } catch (_) {
        _childProcess!.kill();
      }
      try {
        await _childProcess!.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        try {
          _childProcess!.kill(ProcessSignal.sigkill);
        } catch (_) {
          _childProcess!.kill();
        }
      }
    }
    _childProcess = null;
  }

  Future<void> _shutdown() async {
    if (_isShuttingDown) return;
    _isShuttingDown = true;

    KeyboardInputHandler.markShuttingDown();
    await _keyboardHandler?.stop();

    _debounceTimer?.cancel();
    for (final sub in _fileWatchers) {
      await sub.cancel();
    }
    _fileWatchers.clear();

    await _killChild();

    print('👋 Stopped');
    exit(0);
  }
}
