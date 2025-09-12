/// Tracks hot reload and hot restart events for analytics and debugging.
///
/// Maintains a history of reload events with timing information, success/failure
/// status, and error details to help developers understand reload performance
/// and troubleshoot issues.
class ReloadHistory {
  final List<ReloadEvent> _events = [];
  final int _maxEvents = 1000; // Keep last 1000 events

  /// Adds a new reload event to the history.
  void addEvent({
    required String serviceName,
    required String type, // 'hot_reload', 'hot_restart', 'failed'
    required Duration duration,
    String? error,
    List<String>? changedFiles,
  }) {
    final event = ReloadEvent(
      serviceName: serviceName,
      type: type,
      duration: duration,
      timestamp: DateTime.now(),
      error: error,
      changedFiles: changedFiles ?? [],
    );

    _events.add(event);

    // Remove old events to maintain memory efficiency
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
  }

  /// Gets the most recent reload events, limited by the specified count.
  List<Map<String, dynamic>> getRecentEvents({int limit = 50}) {
    final recentEvents = _events.length > limit
        ? _events.sublist(_events.length - limit)
        : _events;

    return recentEvents.reversed.map((event) => event.toMap()).toList();
  }

  /// Gets all events for a specific service.
  List<Map<String, dynamic>> getEventsForService(String serviceName) {
    return _events
        .where((event) => event.serviceName == serviceName)
        .map((event) => event.toMap())
        .toList();
  }

  /// Gets reload statistics for performance analysis.
  Map<String, dynamic> getStatistics() {
    if (_events.isEmpty) {
      return {
        'totalEvents': 0,
        'successfulReloads': 0,
        'failedReloads': 0,
        'averageDuration': 0,
        'successRate': 0.0,
        'recentPerformance': [],
      };
    }

    final successful = _events.where((e) => e.type != 'failed').length;
    final failed = _events.where((e) => e.type == 'failed').length;
    final totalDuration = _events.fold<int>(
      0,
      (sum, event) => sum + event.duration.inMilliseconds,
    );

    // Get performance trend for last 20 events
    final recentEvents =
        _events.length > 20 ? _events.sublist(_events.length - 20) : _events;

    final recentPerformance = recentEvents
        .map((event) => {
              'timestamp': event.timestamp.toIso8601String(),
              'duration': event.duration.inMilliseconds,
              'type': event.type,
              'success': event.type != 'failed',
            })
        .toList();

    return {
      'totalEvents': _events.length,
      'successfulReloads': successful,
      'failedReloads': failed,
      'averageDuration':
          _events.isNotEmpty ? totalDuration / _events.length : 0,
      'successRate':
          _events.isNotEmpty ? (successful / _events.length * 100) : 0.0,
      'recentPerformance': recentPerformance,
      'serviceBreakdown': _getServiceBreakdown(),
    };
  }

  /// Gets reload count and performance by service.
  Map<String, Map<String, dynamic>> _getServiceBreakdown() {
    final breakdown = <String, Map<String, dynamic>>{};

    for (final event in _events) {
      final serviceName = event.serviceName;

      if (!breakdown.containsKey(serviceName)) {
        breakdown[serviceName] = {
          'total': 0,
          'successful': 0,
          'failed': 0,
          'totalDuration': 0,
        };
      }

      breakdown[serviceName]!['total'] =
          (breakdown[serviceName]!['total'] as int) + 1;

      if (event.type == 'failed') {
        breakdown[serviceName]!['failed'] =
            (breakdown[serviceName]!['failed'] as int) + 1;
      } else {
        breakdown[serviceName]!['successful'] =
            (breakdown[serviceName]!['successful'] as int) + 1;
      }

      breakdown[serviceName]!['totalDuration'] =
          (breakdown[serviceName]!['totalDuration'] as int) +
              event.duration.inMilliseconds;
    }

    // Calculate averages
    breakdown.forEach((serviceName, stats) {
      final total = stats['total'] as int;
      if (total > 0) {
        stats['averageDuration'] = (stats['totalDuration'] as int) / total;
        stats['successRate'] = (stats['successful'] as int) / total * 100;
      } else {
        stats['averageDuration'] = 0;
        stats['successRate'] = 0.0;
      }
    });

    return breakdown;
  }

  /// Clears all reload history (useful for testing or reset).
  void clear() {
    _events.clear();
  }

  /// Gets the total number of recorded events.
  int get totalEvents => _events.length;

  /// Gets events from the last specified duration.
  List<Map<String, dynamic>> getEventsInTimeRange(Duration timeRange) {
    final cutoff = DateTime.now().subtract(timeRange);
    return _events
        .where((event) => event.timestamp.isAfter(cutoff))
        .map((event) => event.toMap())
        .toList();
  }
}

/// Represents a single hot reload or restart event.
class ReloadEvent {
  final String serviceName;
  final String type; // 'hot_reload', 'hot_restart', 'failed'
  final Duration duration;
  final DateTime timestamp;
  final String? error;
  final List<String> changedFiles;

  ReloadEvent({
    required this.serviceName,
    required this.type,
    required this.duration,
    required this.timestamp,
    this.error,
    required this.changedFiles,
  });

  /// Converts the event to a map for JSON serialization.
  Map<String, dynamic> toMap() {
    return {
      'serviceName': serviceName,
      'type': type,
      'duration': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'changedFiles': changedFiles,
      'success': type != 'failed',
    };
  }

  /// Creates a ReloadEvent from a map (for deserialization).
  factory ReloadEvent.fromMap(Map<String, dynamic> map) {
    return ReloadEvent(
      serviceName: map['serviceName'] as String,
      type: map['type'] as String,
      duration: Duration(milliseconds: map['duration'] as int),
      timestamp: DateTime.parse(map['timestamp'] as String),
      error: map['error'] as String?,
      changedFiles: List<String>.from(map['changedFiles'] ?? []),
    );
  }

  @override
  String toString() {
    return 'ReloadEvent(service: $serviceName, type: $type, '
        'duration: ${duration.inMilliseconds}ms, '
        'timestamp: ${timestamp.toIso8601String()})';
  }
}
