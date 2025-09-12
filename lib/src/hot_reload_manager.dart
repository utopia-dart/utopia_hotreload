import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'reload_mode.dart';
import 'file_watcher.dart';

/// Manages hot reload functionality using Dart VM service for true state preservation.
///
/// This implementation provides Flutter-like hot reload capabilities by connecting
/// to the VM service and using the `reloadSources()` API to update code without
/// losing application state.
class HotReloadManager {
  final ReloadConfig config;
  final Future<void> Function() script;

  VmService? _vmService;
  HotReloadFileWatcher? _fileWatcher;
  String? _isolateId;
  bool _isReloading = false;

  /// Creates a new hot reload manager with the given [script] and [config].
  HotReloadManager({
    required this.script,
    required this.config,
  });

  /// Starts the hot reload development server.
  Future<void> start() async {
    print('🚀 Starting Development Server with True Hot Reload...');
    print('📁 Watching paths: ${config.watchPaths}');
    print('📄 Watching extensions: ${config.watchExtensions}');
    print('🔥 True hot reload enabled - state will be preserved');
    print('');

    await _enableVmService();
    await _connectToVmService();

    ProcessSignal.sigint.watch().listen((signal) async {
      print('\\n🛑 Shutting down development server...');
      await _shutdown();
      exit(0);
    });

    _fileWatcher = HotReloadFileWatcher(config);
    await _fileWatcher!.start((_) => _performHotReload());

    print('');

    print('🔄 Starting application...');
    await script();
  }

  /// Enables VM service if not already enabled by restarting the process.
  Future<void> _enableVmService() async {
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

    if (!Platform.executableArguments.contains('--enable-vm-service')) {
      print('🔄 Restarting with VM service enabled...');

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
      } catch (_) {}

      final exitCode = await process.exitCode;
      exit(exitCode);
    }
  }

  /// Connects to the VM service for hot reload functionality.
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

  /// Performs hot reload using the VM service to preserve application state.
  Future<void> _performHotReload() async {
    if (_isReloading) return;
    if (_vmService == null || _isolateId == null) {
      print('❌ VM service not available, cannot perform hot reload');
      return;
    }

    _isReloading = true;

    try {
      print('🔥 Performing hot reload...');

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
      }
    } catch (e) {
      print('❌ Hot reload error: $e');
    } finally {
      _isReloading = false;
    }
  }

  /// Shuts down the manager and cleans up resources.
  Future<void> _shutdown() async {
    await _fileWatcher?.stop();
    await _vmService?.dispose();
    print('✅ Development server stopped');
  }
}
