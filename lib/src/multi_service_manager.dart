import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'service_config.dart';
import 'reload_config.dart';
import 'file_watcher.dart';
import 'keyboard_input_handler.dart';
import 'dashboard/dashboard_service.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Manages multiple services in a development environment with coordinated hot reload.
///
/// Allows running multiple scripts/services simultaneously, each with their own
/// configuration and reload behavior, while providing unified control and monitoring.
class MultiServiceManager {
  final List<ServiceConfig> _services;
  final ReloadConfig _globalConfig;
  final Map<String, ServiceInstance> _runningServices = {};
  final Map<String, HotReloadFileWatcher> _watchers = {};
  final List<StreamSubscription> _subscriptions = [];
  final Set<String> _restartingServices = {};

  KeyboardInputHandler? _keyboardHandler;
  bool _isShuttingDown = false;

  // Optional dashboard for recording reload events
  DashboardService? _dashboardService;

  /// Creates a new multi-service manager.
  MultiServiceManager(this._services, this._globalConfig);

  /// Starts all configured services that have [autoStart] enabled.
  ///
  /// Services are started in priority order (highest priority first).
  /// Each service gets its own file watcher and reload manager.
  ///
  /// [interactive] - whether to start the interactive command mode (default: true)
  Future<void> startAll({bool interactive = true}) async {
    print('🚀 Starting multi-service development environment...');
    print('📋 Configured services: ${_services.length}');
    print('');

    // Sort services by priority (highest first)
    final servicesToStart = _services
        .where((service) => service.autoStart)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final service in servicesToStart) {
      await _startService(service);
    }

    print('');
    print('✅ All services started successfully!');
    _printServiceStatus();

    if (interactive) {
      _startInteractiveMode();
    }
  }

  /// Starts a specific service by name.
  Future<void> startService(String serviceName) async {
    final service = _services.firstWhere(
      (s) => s.name == serviceName,
      orElse: () => throw ArgumentError('Service not found: $serviceName'),
    );

    await _startService(service);
  }

  /// Stops a specific service by name.
  Future<void> stopService(String serviceName) async {
    final instance = _runningServices[serviceName];
    if (instance == null) {
      print('⚠️  Service not running: $serviceName');
      return;
    }

    print('[STOP] Stopping service: ${instance.config.effectiveDisplayName}');
    await _stopService(serviceName);
  }

  /// Restarts a specific service by name.
  Future<void> restartService(String serviceName) async {
    if (_runningServices.containsKey(serviceName)) {
      await stopService(serviceName);
    }
    await startService(serviceName);
  }

  /// Triggers hot restart for all running services.
  Future<void> hotRestartAll() async {
    print('🔄 Hot restarting all services...');
    for (final instance in _runningServices.values) {
      await _restartService(instance);
    }
    print('✅ Hot restart completed for all services');
  }

  /// Triggers hot restart for a specific service.
  Future<void> hotRestartService(String serviceName) async {
    final instance = _runningServices[serviceName];
    if (instance == null) {
      print('⚠️  Service not running: $serviceName');
      return;
    }

    print('🔄 Hot restarting service: ${instance.config.effectiveDisplayName}');
    await _restartService(instance);
  }

  /// Shuts down all services and cleanup resources.
  Future<void> shutdown() async {
    if (_isShuttingDown) return;
    _isShuttingDown = true;

    print('');
    print('👋 Shutting down multi-service environment...');

    // Mark keyboard handler as shutting down to prevent Windows VM crashes
    KeyboardInputHandler.markShuttingDown();

    // Stop keyboard input handler
    await _keyboardHandler?.stop();

    // Stop all file watchers
    for (final watcher in _watchers.values) {
      await watcher.stop();
    }

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }

    // Stop all services
    final serviceNames = _runningServices.keys.toList();
    for (final serviceName in serviceNames) {
      await _stopService(serviceName);
    }

    print('✅ All services shut down successfully');
  }

  /// Lists all configured services and their status.
  void listServices() {
    print('📋 Service Status:');
    print('─' * 60);
    for (final service in _services) {
      final isRunning = _runningServices.containsKey(service.name);
      final status = isRunning ? '🟢 RUNNING' : '⚪ STOPPED';
      final autoStart = service.autoStart ? '(auto)' : '(manual)';
      print(
          '  ${service.effectiveDisplayName.padRight(20)} $status $autoStart');
    }
    print('');
  }

  /// Attaches a dashboard service for recording reload events and metrics.
  void attachDashboard(DashboardService dashboard) {
    _dashboardService = dashboard;
  }

  /// Records a reload event to the dashboard if available.
  void _recordReloadEvent({
    required String serviceName,
    required String type,
    required Duration duration,
    String? error,
    List<String>? changedFiles,
  }) {
    _dashboardService?.recordReloadEvent(
      serviceName: serviceName,
      type: type,
      duration: duration,
      error: error,
      changedFiles: changedFiles,
    );
  }

  Future<void> _startService(ServiceConfig service) async {
    if (_runningServices.containsKey(service.name)) {
      print('⚠️  Service already running: ${service.effectiveDisplayName}');
      return;
    }

    print('🚀 Starting service: ${service.effectiveDisplayName}');

    try {
      // Create service-specific reload config
      final serviceConfig = _createServiceReloadConfig(service);

      // Start the service process
      final process = await _startServiceProcess(service);

      // Create and start file watcher for this service
      final watcher = HotReloadFileWatcher(serviceConfig);
      await watcher.start((filePath) {
        if (serviceConfig.verbose) {
          print('📝 [${service.effectiveDisplayName}] File changed: $filePath');
        }
        _triggerServiceRestart(service.name);
      });

      // Store service instance
      final instance = ServiceInstance(
        config: service,
        process: process,
      );

      _runningServices[service.name] = instance;
      _watchers[service.name] = watcher;

      print('✅ Service started: ${service.effectiveDisplayName}');
    } catch (e) {
      print('❌ Failed to start service ${service.effectiveDisplayName}: $e');
      rethrow;
    }
  }

  Future<Process> _startServiceProcess(ServiceConfig service) async {
    final scriptPath = Platform.script.toFilePath();

    final parentArgs = Platform.executableArguments.where((arg) {
      return !(arg.startsWith('--enable-vm-service') ||
          arg.startsWith('--observe') ||
          arg.startsWith('--disable-service-auth-codes'));
    }).toList();

    final vmPort = service.vmServicePort ?? 0;
    final args = [
      '--enable-vm-service=$vmPort',
      '--disable-service-auth-codes',
      ...parentArgs,
      scriptPath,
    ];

    final environment = Map<String, String>.from(Platform.environment);
    environment.addAll(service.environment);
    environment['UTOPIA_DEV_MODE'] = 'true';
    environment['UTOPIA_SERVICE_NAME'] = service.name;

    final process = await Process.start(
      Platform.executable,
      args,
      workingDirectory: service.workingDirectory ?? Directory.current.path,
      environment: environment,
    );

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[${service.effectiveDisplayName}] $line');
      _maybeCaptureVmServiceUri(service.name, line);
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[${service.effectiveDisplayName}] ERROR: $line');
      _maybeCaptureVmServiceUri(service.name, line);
    });

    return process;
  }

  void _maybeCaptureVmServiceUri(String serviceName, String line) {
    final marker = 'The Dart VM service is listening on ';
    final idx = line.indexOf(marker);
    if (idx == -1) return;
    final uriStr = line.substring(idx + marker.length).trim();
    _connectToChildVmService(serviceName, uriStr);
  }

  Future<void> _connectToChildVmService(
      String serviceName, String httpUri) async {
    final instance = _runningServices[serviceName];
    if (instance == null || instance.vmConnected) return;
    instance.vmConnected = true;
    try {
      var wsUri = httpUri.replaceFirst('http', 'ws');
      if (!wsUri.endsWith('/ws')) {
        if (!wsUri.endsWith('/')) wsUri = '$wsUri/';
        wsUri = '${wsUri}ws';
      }
      final service = await vmServiceConnectUri(wsUri);
      final vm = await service.getVM();
      if (vm.isolates?.isNotEmpty == true) {
        instance.isolateId = vm.isolates!.first.id!;
        instance.vmService = service;
        print(
            '✅ [${instance.config.effectiveDisplayName}] Connected to VM service - hot reload enabled');
      } else {
        instance.vmConnected = false;
        try {
          await service.dispose();
        } catch (_) {}
      }
    } catch (e) {
      instance.vmConnected = false;
      if (_globalConfig.verbose) {
        print(
            '⚠️  [${instance.config.effectiveDisplayName}] Failed to connect to VM service: $e');
      }
    }
  }

  Future<void> _stopService(String serviceName) async {
    final instance = _runningServices.remove(serviceName);
    final watcher = _watchers.remove(serviceName);

    if (instance != null) {
      // Clean up VM service connection
      if (instance.vmService != null) {
        try {
          final svc = instance.vmService;
          instance.vmService = null;
          instance.vmConnected = false;
          instance.isolateId = null;
          await svc?.dispose();
        } catch (_) {}
      }

      await _killProcess(instance.process);
    }

    if (watcher != null) {
      await watcher.stop();
    }

    print('✅ Service stopped: $serviceName');
  }

  Future<void> _restartService(ServiceInstance instance) async {
    final stopwatch = Stopwatch()..start();

    // Try hot reload first if VM service is connected
    if (instance.vmConnected &&
        instance.vmService != null &&
        instance.isolateId != null) {
      try {
        print(
            '🔥 [${instance.config.effectiveDisplayName}] Performing hot reload...');
        final report =
            await instance.vmService!.reloadSources(instance.isolateId!);
        stopwatch.stop();

        if (report.success == true) {
          print(
              '✅ [${instance.config.effectiveDisplayName}] Hot reload completed');
          _recordReloadEvent(
            serviceName: instance.config.name,
            type: 'hot_reload',
            duration: stopwatch.elapsed,
          );
          return;
        }
        print(
            '⚠️  [${instance.config.effectiveDisplayName}] Hot reload failed, falling back to restart...');
      } catch (e) {
        print(
            '⚠️  [${instance.config.effectiveDisplayName}] Hot reload error: $e, falling back to restart...');
      }
      stopwatch.reset();
      stopwatch.start();
    }

    // Fall back to full process restart
    print(
        '🔄 [${instance.config.effectiveDisplayName}] Performing hot restart...');

    try {
      // Clean up VM service connection
      if (instance.vmService != null) {
        try {
          final svc = instance.vmService;
          instance.vmService = null;
          instance.vmConnected = false;
          instance.isolateId = null;
          await svc?.dispose();
        } catch (_) {}
      }

      // Stop the current process
      await _killProcess(instance.process);

      // Start a new process
      final newProcess = await _startServiceProcess(instance.config);
      instance.process = newProcess;

      stopwatch.stop();

      _recordReloadEvent(
        serviceName: instance.config.name,
        type: 'hot_restart',
        duration: stopwatch.elapsed,
      );

      print(
          '✅ [${instance.config.effectiveDisplayName}] Hot restart completed');
    } catch (e) {
      stopwatch.stop();

      _recordReloadEvent(
        serviceName: instance.config.name,
        type: 'failed',
        duration: stopwatch.elapsed,
        error: e.toString(),
      );

      print(
          '❌ [${instance.config.effectiveDisplayName}] Failed to restart: $e');
      rethrow;
    }
  }

  void _triggerServiceRestart(String serviceName) {
    final instance = _runningServices[serviceName];
    if (instance == null) return;
    if (_restartingServices.contains(serviceName)) return;
    _restartingServices.add(serviceName);
    _restartService(instance).catchError((e) {
      print('❌ [$serviceName] Restart failed: $e');
    }).whenComplete(() {
      _restartingServices.remove(serviceName);
    });
  }

  ReloadConfig _createServiceReloadConfig(ServiceConfig service) {
    return ReloadConfig(
      mode: _globalConfig.mode,
      watchPaths: service.watchPaths ?? _globalConfig.watchPaths,
      watchExtensions: service.watchExtensions ?? _globalConfig.watchExtensions,
      ignorePatterns: service.ignorePatterns ?? _globalConfig.ignorePatterns,
      debounceDelay: _globalConfig.debounceDelay,
      verbose: service.verbose ?? _globalConfig.verbose,
      childVmServicePort:
          service.vmServicePort ?? _globalConfig.childVmServicePort,
    );
  }

  void _printServiceStatus() {
    print('📊 Service Summary:');
    print('  Total services: ${_services.length}');
    print('  Running services: ${_runningServices.length}');
    print(
        '  Auto-start services: ${_services.where((s) => s.autoStart).length}');
  }

  void _startInteractiveMode() {
    _keyboardHandler = KeyboardInputHandler(
      onCtrlC: () => _handleShutdown(),
      onShutdown: () => _handleShutdown(),
    );

    // Register command handlers
    _keyboardHandler!.registerCommand('r', () {
      print('🔄 Hot restarting all services...');
      hotRestartAll();
    });

    _keyboardHandler!.registerCommand('l', () {
      print('📋 Listing services...');
      listServices();
    });

    _keyboardHandler!.registerCommand('s', () {
      print('[STOP] Stopping services...');
      _listAndStopServices();
    });

    _keyboardHandler!.registerCommand('t', () {
      print('🚀 Starting services...');
      _listAndStartServices();
    });

    _keyboardHandler!.registerCommand('q', () {
      print('👋 Shutting down all services...');
      _handleShutdown();
    });

    // Start listening with help text
    final helpText = '''
💡 Multi-service commands available:
  r: Hot restart all services
  l: List service status
  s: Stop all running services
  t: Start all stopped services
  q: Quit all services
  Ctrl+C: Force quit

🎮 Background keyboard input enabled...
💡 Press: r (restart), l (list), s (stop), t (start), q (quit), or Ctrl+C''';

    _keyboardHandler!.start(helpText: helpText);
  }

  void _handleShutdown() {
    shutdown().then((_) => exit(0));
  }

  Future<void> _killProcess(Process process) async {
    if (Platform.isWindows) {
      process.kill();
      try {
        await process.exitCode.timeout(Duration(seconds: 2));
      } catch (_) {}
    } else {
      try {
        process.kill(ProcessSignal.sigterm);
      } catch (_) {
        process.kill();
      }
      try {
        await process.exitCode.timeout(Duration(seconds: 2));
      } catch (_) {
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {
          process.kill();
        }
      }
    }
  }

  Future<void> _listAndStopServices() async {
    final runningServices = _runningServices.keys.toList();
    if (runningServices.isEmpty) {
      print('ℹ️  No services are currently running');
      return;
    }

    print('[STOP] Running services (will stop all):');
    for (final serviceName in runningServices) {
      print('  • $serviceName');
    }

    // Stop all running services for simplicity
    print('💡 Stopping all running services...');
    for (final serviceName in runningServices) {
      await _stopService(serviceName);
    }
  }

  Future<void> _listAndStartServices() async {
    final stoppedServices =
        _services.where((s) => !_runningServices.containsKey(s.name)).toList();
    if (stoppedServices.isEmpty) {
      print('ℹ️  All services are already running');
      return;
    }

    print('🚀 Stopped services (will start all):');
    for (final service in stoppedServices) {
      print('  • ${service.name}');
    }

    // Start all stopped services for simplicity
    print('💡 Starting all stopped services...');
    for (final service in stoppedServices) {
      await startService(service.name);
    }
  }

  /// Gets all configured services.
  List<ServiceConfig> getServices() {
    return List.unmodifiable(_services);
  }

  /// Gets all currently running service instances.
  Map<String, ServiceInstance> getRunningServices() {
    return Map.unmodifiable(_runningServices);
  }

  /// Gets the status of all services for dashboard display.
  List<Map<String, dynamic>> getServiceStatuses() {
    return _services.map((service) {
      final isRunning = _runningServices.containsKey(service.name);
      return {
        'name': service.name,
        'displayName': service.effectiveDisplayName,
        'status': isRunning ? 'running' : 'stopped',
        'priority': service.priority,
        'autoStart': service.autoStart,
        'watchPaths': service.watchPaths,
        'environment': service.environment,
      };
    }).toList();
  }

  /// Gets comprehensive information about all watched files across all services.
  Map<String, dynamic> getAllWatchedFiles() {
    final result = <String, dynamic>{
      'services': <Map<String, dynamic>>[],
      'totalWatchers': _watchers.length,
      'totalWatchPaths': 0,
      'totalPatterns': 0,
      'summary': <String, int>{},
    };

    final allWatchPaths = <String>{};
    var totalPatterns = 0;

    for (final entry in _watchers.entries) {
      final serviceName = entry.key;
      final watcher = entry.value;
      final watchInfo = watcher.getWatchInfo();

      allWatchPaths.addAll(watchInfo['watchPaths'] as List<String>);
      totalPatterns += watchInfo['matcherInfo']['patternCount'] as int;

      result['services'].add({
        'serviceName': serviceName,
        'isActive': watchInfo['isActive'],
        'watchPaths': watchInfo['watchPaths'],
        'debounceMs': watchInfo['debounceMs'],
        'matcher': watchInfo['matcherInfo'],
      });
    }

    result['totalWatchPaths'] = allWatchPaths.length;
    result['totalPatterns'] = totalPatterns;
    result['uniqueWatchPaths'] = allWatchPaths.toList()..sort();

    // Create summary by file extension
    final extensionCounts = <String, int>{};
    for (final path in allWatchPaths) {
      final extension = path.split('.').last.toLowerCase();
      extensionCounts[extension] = (extensionCounts[extension] ?? 0) + 1;
    }
    result['summary'] = extensionCounts;

    return result;
  }
}

/// Represents a running service instance.
class ServiceInstance {
  final ServiceConfig config;
  Process process;
  VmService? vmService;
  String? isolateId;
  bool vmConnected = false;

  ServiceInstance({
    required this.config,
    required this.process,
  });
}
