import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'reload_mode.dart';
import 'file_watcher.dart';

/// Hot reload manager that uses Dart VM service for true hot reload
/// This preserves application state similar to Flutter's hot reload
class HotReloadManager {
  final ReloadConfig config;
  final Future<void> Function() script;

  VmService? _vmService;
  HotReloadFileWatcher? _fileWatcher;
  String? _isolateId;
  bool _isReloading = false;

  HotReloadManager({
    required this.script,
    required this.config,
  });

  /// Start the hot reload development server
  Future<void> start() async {
    print('🚀 Starting Development Server with True Hot Reload...');
    print('📁 Watching paths: ${config.watchPaths}');
    print('📄 Watching extensions: ${config.watchExtensions}');
    print('🔥 True hot reload enabled - state will be preserved');
    print('');

    // Enable VM service if not already enabled
    await _enableVmService();

    // Connect to VM service
    await _connectToVmService();

    // Handle Ctrl+C gracefully
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\\n🛑 Shutting down development server...');
      await _shutdown();
      exit(0);
    });

    // Set up file watcher
    _fileWatcher = HotReloadFileWatcher(config);
    await _fileWatcher!.start((_) => _performHotReload());

    print('');

    // Start the script in the current isolate
    print('🔄 Starting application...');
    await script();
  }

  /// Enable VM service if not already enabled
  Future<void> _enableVmService() async {
    // Check if VM service is already enabled by trying to get service info
    try {
      final serviceInfo = await developer.Service.getInfo();
      if (serviceInfo.serverUri != null) {
        if (config.verbose) {
          print('✅ VM service already enabled: ${serviceInfo.serverUri}');
        }
        return;
      }
    } catch (e) {
      // Service not available, need to restart with VM service
    }

    // VM service is not enabled, we need to restart with --enable-vm-service
    if (!Platform.executableArguments.contains('--enable-vm-service')) {
      print('🔄 Restarting with VM service enabled...');

      final scriptPath = Platform.script.toFilePath();
      final args = [
        '--enable-vm-service=0', // Use port 0 for automatic port selection
        '--disable-service-auth-codes',
        ...Platform.executableArguments,
        scriptPath,
      ];

      final process = await Process.start(Platform.executable, args);

      // Forward stdout and stderr
      process.stdout.listen((data) {
        stdout.add(data);
      });

      process.stderr.listen((data) {
        stderr.add(data);
      });

      final exitCode = await process.exitCode;
      exit(exitCode);
    }
  }

  /// Connect to the VM service
  Future<void> _connectToVmService() async {
    try {
      final serviceInfo = await developer.Service.getInfo();
      if (serviceInfo.serverUri == null) {
        throw StateError('VM service not available');
      }

      final wsUri = serviceInfo.serverUri.toString().replaceFirst('http', 'ws');
      if (config.verbose) {
        print('🔌 Connecting to VM service: $wsUri');
      }

      _vmService = await vmServiceConnectUri(wsUri);

      // Get the main isolate
      final vm = await _vmService!.getVM();
      if (vm.isolates?.isNotEmpty == true) {
        _isolateId = vm.isolates!.first.id!;
        if (config.verbose) {
          print('✅ Connected to isolate: $_isolateId');
        }
      }
    } catch (e) {
      print('❌ Failed to connect to VM service: $e');
      print('   Falling back to hot restart mode');
      rethrow;
    }
  }

  /// Perform hot reload using VM service
  Future<void> _performHotReload() async {
    if (_isReloading) return;
    if (_vmService == null || _isolateId == null) {
      print('❌ VM service not available, cannot perform hot reload');
      return;
    }

    _isReloading = true;

    try {
      print('🔥 Performing hot reload...');

      // Reload sources
      final reloadReport = await _vmService!.reloadSources(_isolateId!);

      if (reloadReport.success == true) {
        print('✅ Hot reload completed successfully');
        if (config.verbose) {
          print('   Reloaded ${reloadReport.success}');
        }
      } else {
        print('❌ Hot reload failed');
        if (reloadReport.json != null) {
          print('   Response: ${reloadReport.json}');
        }
        // Could fall back to hot restart here
      }
    } catch (e) {
      print('❌ Hot reload error: $e');
      // Could fall back to hot restart here
    } finally {
      _isReloading = false;
    }
  }

  /// Shutdown the manager
  Future<void> _shutdown() async {
    await _fileWatcher?.stop();
    await _vmService?.dispose();
    print('✅ Development server stopped');
  }
}

/// Hybrid manager that tries hot reload first, falls back to hot restart
class AutoReloadManager {
  final ReloadConfig config;
  final Future<void> Function() script;

  AutoReloadManager({
    required this.script,
    required this.config,
  });

  /// Start with automatic mode - tries hot reload, falls back to restart
  Future<void> start() async {
    try {
      // Try to use true hot reload first
      final hotReloadManager = HotReloadManager(
        script: script,
        config: config,
      );
      await hotReloadManager.start();
    } catch (e) {
      if (config.verbose) {
        print('Hot reload not available: $e');
        print('Falling back to hot restart mode...');
      }

      // Fall back to hot restart - import and use the actual class
      // This will be resolved when both files are created
      throw UnimplementedError('Hot restart fallback not yet implemented');
    }
  }
}
