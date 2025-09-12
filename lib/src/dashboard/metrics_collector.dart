import 'dart:async';
import 'dart:io';

import '../multi_service_manager.dart';

/// Collects and tracks performance metrics for the hot reload dashboard.
///
/// Monitors system resources, service performance, and reload statistics
/// to provide insights into development environment health and efficiency.
class MetricsCollector {
  final DateTime _startTime = DateTime.now();
  MultiServiceManager? _serviceManager;

  final List<int> _reloadTimes = [];
  int _totalReloads = 0;
  int _successfulReloads = 0;
  int _failedReloads = 0;

  late Timer _metricsTimer;
  Map<String, dynamic> _cachedMetrics = {};

  MetricsCollector() {
    _startMetricsCollection();
  }

  /// Attaches a service manager for monitoring service-specific metrics.
  void attachServiceManager(MultiServiceManager manager) {
    _serviceManager = manager;
  }

  /// Records a reload event for performance tracking.
  void recordReload({
    required Duration duration,
    required bool success,
    String? serviceName,
  }) {
    _totalReloads++;
    _reloadTimes.add(duration.inMilliseconds);

    if (success) {
      _successfulReloads++;
    } else {
      _failedReloads++;
    }

    // Keep only last 100 reload times for memory efficiency
    if (_reloadTimes.length > 100) {
      _reloadTimes.removeAt(0);
    }
  }

  /// Gets the system uptime in seconds.
  int getUptime() {
    return DateTime.now().difference(_startTime).inSeconds;
  }

  /// Collects comprehensive metrics about the system and services.
  Future<Map<String, dynamic>> collectMetrics() async {
    final metrics = <String, dynamic>{
      'uptime': getUptime(),
      'totalReloads': _totalReloads,
      'successfulReloads': _successfulReloads,
      'failedReloads': _failedReloads,
      'successRate': _totalReloads > 0
          ? (_successfulReloads / _totalReloads * 100).toStringAsFixed(1)
          : '0.0',
      'averageReloadTime': _calculateAverageReloadTime(),
      'memoryUsage': await _getMemoryUsage(),
      'fileWatches': _getActiveFileWatches(),
      'connectedClients': 0, // Will be set by dashboard service
      'serviceMetrics': _getServiceMetrics(),
      'platformInfo': _getPlatformInfo(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    _cachedMetrics = metrics;
    return metrics;
  }

  /// Gets cached metrics without recalculation (for frequent updates).
  Map<String, dynamic> getCachedMetrics() {
    return Map.from(_cachedMetrics);
  }

  void _startMetricsCollection() {
    // Update metrics cache every 5 seconds
    _metricsTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      await collectMetrics();
    });
  }

  void dispose() {
    _metricsTimer.cancel();
  }

  double _calculateAverageReloadTime() {
    if (_reloadTimes.isEmpty) return 0.0;

    final sum = _reloadTimes.reduce((a, b) => a + b);
    return sum / _reloadTimes.length;
  }

  Future<int> _getMemoryUsage() async {
    try {
      // Get current process memory usage
      final processInfo =
          await Process.run('tasklist', ['/fi', 'PID eq $pid', '/fo', 'csv']);
      if (processInfo.exitCode == 0) {
        final lines = processInfo.stdout.toString().split('\n');
        if (lines.length > 1) {
          final memoryColumn = lines[1].split(',');
          if (memoryColumn.length > 4) {
            final memoryStr = memoryColumn[4]
                .replaceAll('"', '')
                .replaceAll(',', '')
                .replaceAll(' K', '');
            return int.tryParse(memoryStr) ?? 0;
          }
        }
      }
    } catch (e) {
      // Fallback for non-Windows or if tasklist fails
      try {
        final result =
            await Process.run('ps', ['-o', 'rss=', '-p', pid.toString()]);
        if (result.exitCode == 0) {
          final memoryKb = int.tryParse(result.stdout.toString().trim()) ?? 0;
          return memoryKb;
        }
      } catch (e2) {
        // If both methods fail, return 0
      }
    }
    return 0;
  }

  int _getActiveFileWatches() {
    // This would need to be implemented by integrating with the file watcher
    // For now, return an estimated count based on services
    if (_serviceManager == null) return 0;

    // Estimate based on number of services and average watch paths
    return _serviceManager!.getServices().length * 2; // Rough estimate
  }

  Map<String, dynamic> _getServiceMetrics() {
    if (_serviceManager == null) {
      return {
        'totalServices': 0,
        'runningServices': 0,
        'stoppedServices': 0,
        'services': <Map<String, dynamic>>[],
      };
    }

    final services = _serviceManager!.getServices();
    final runningServices = _serviceManager!.getRunningServices();

    final serviceList = services.map((service) {
      final isRunning = runningServices.containsKey(service.name);
      return {
        'name': service.name,
        'displayName': service.effectiveDisplayName,
        'status': isRunning ? 'running' : 'stopped',
        'priority': service.priority,
        'autoStart': service.autoStart,
        'uptime': isRunning ? _getServiceUptime(service.name) : 0,
      };
    }).toList();

    return {
      'totalServices': services.length,
      'runningServices': runningServices.length,
      'stoppedServices': services.length - runningServices.length,
      'services': serviceList,
    };
  }

  int _getServiceUptime(String serviceName) {
    // This would need to be tracked by the service manager
    // For now, return a placeholder
    return getUptime(); // Assume service started with the system
  }

  Map<String, dynamic> _getPlatformInfo() {
    return {
      'platform': Platform.operatingSystem,
      'architecture': Platform.version.split(' ').first,
      'dartVersion': Platform.version,
      'executablePath': Platform.resolvedExecutable,
      'processId': pid,
    };
  }
}
