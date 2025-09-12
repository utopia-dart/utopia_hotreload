import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'service_config.dart';
import 'reload_config.dart';
import 'file_watcher.dart';
import 'keyboard_input_handler.dart';

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

  KeyboardInputHandler? _keyboardHandler;
  bool _isShuttingDown = false;

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

    print('� Hot restarting service: ${instance.config.effectiveDisplayName}');
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
    // Create a temporary script file for this service
    final tempDir = Directory.systemTemp.createTempSync('utopia_service_');
    final scriptFile = File('${tempDir.path}/service_${service.name}.dart');

    // Write a script that calls the service function
    final scriptContent = '''
import 'dart:async';
import 'dart:io';

// Import user's script (this is a simplified approach)
// In a real implementation, we'd use a more sophisticated approach
Future<void> main() async {
  print('🚀 Starting service: ${service.effectiveDisplayName}');
  
  // Call the service script
  // Note: This is a placeholder - in a real implementation,
  // we'd need a more sophisticated way to serialize and call the function
  await runServiceScript();
}

Future<void> runServiceScript() async {
  // Placeholder - this would be replaced with the actual service script
  print('Service ${service.name} is running...');
  
  // Keep the service running
  while (true) {
    await Future.delayed(Duration(seconds: 1));
  }
}
''';

    await scriptFile.writeAsString(scriptContent);

    // Start the process
    final process = await Process.start(
      Platform.resolvedExecutable,
      [scriptFile.path],
      workingDirectory: service.workingDirectory ?? Directory.current.path,
      environment: {
        ...Platform.environment,
        ...service.environment,
      },
    );

    // Monitor process output
    process.stdout.transform(utf8.decoder).listen((data) {
      print('[${service.effectiveDisplayName}] $data');
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      print('[${service.effectiveDisplayName}] ERROR: $data');
    });

    return process;
  }

  Future<void> _stopService(String serviceName) async {
    final instance = _runningServices.remove(serviceName);
    final watcher = _watchers.remove(serviceName);

    if (instance != null) {
      instance.process.kill();
      try {
        await instance.process.exitCode.timeout(Duration(seconds: 2));
      } catch (e) {
        instance.process.kill(ProcessSignal.sigkill);
      }
    }

    if (watcher != null) {
      await watcher.stop();
    }

    print('✅ Service stopped: $serviceName');
  }

  Future<void> _restartService(ServiceInstance instance) async {
    print('🔄 Restarting service: ${instance.config.effectiveDisplayName}');

    // Stop the current process
    instance.process.kill();
    try {
      await instance.process.exitCode.timeout(Duration(seconds: 2));
    } catch (e) {
      instance.process.kill(ProcessSignal.sigkill);
    }

    // Start a new process
    final newProcess = await _startServiceProcess(instance.config);
    instance.process = newProcess;

    print('✅ Service restarted: ${instance.config.effectiveDisplayName}');
  }

  void _triggerServiceRestart(String serviceName) {
    final instance = _runningServices[serviceName];
    if (instance != null) {
      _restartService(instance);
    }
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
    shutdown();
    exit(0);
  }

  void _listAndStopServices() {
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
      _stopService(serviceName);
    }
  }

  void _listAndStartServices() {
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
      startService(service.name);
    }
  }
}

/// Represents a running service instance.
class ServiceInstance {
  final ServiceConfig config;
  Process process;

  ServiceInstance({
    required this.config,
    required this.process,
  });
}
