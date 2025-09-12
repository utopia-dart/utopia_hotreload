import 'package:test/test.dart';
import 'package:utopia_hotreload/src/dashboard/dashboard_service.dart';
import 'package:utopia_hotreload/src/dashboard/metrics_collector.dart';
import 'package:utopia_hotreload/src/dashboard/reload_history.dart';

void main() {
  group('Dashboard Service', () {
    late DashboardService dashboard;

    setUp(() {
      dashboard = DashboardService(
        host: 'localhost',
        port: 9001, // Use different port for testing
        enabled: true,
      );
    });

    tearDown(() async {
      try {
        await dashboard.stop();
      } catch (e) {
        // Ignore errors during cleanup
      }
    });

    test('should start and stop dashboard service', () async {
      await dashboard.start();
      expect(dashboard.isRunning, isTrue);

      await dashboard.stop();
      expect(dashboard.isRunning, isFalse);
    });

    test('should record reload events', () async {
      await dashboard.start(); // Need to start dashboard first

      dashboard.recordReloadEvent(
        serviceName: 'test-service',
        type: 'hot_reload',
        duration: Duration(milliseconds: 100),
        changedFiles: ['lib/test.dart'],
      );

      dashboard.recordReloadEvent(
        serviceName: 'test-service',
        type: 'hot_restart',
        duration: Duration(milliseconds: 500),
        error: 'Test error',
      );

      // Events should be recorded in the reload history
      expect(dashboard.reloadHistory.totalEvents, equals(2));
    });

    test('should handle disabled dashboard', () async {
      final disabledDashboard = DashboardService(enabled: false);

      // Should not start when disabled
      await disabledDashboard.start();
      expect(disabledDashboard.isRunning, isFalse);
    });
  });

  group('MetricsCollector', () {
    late MetricsCollector collector;

    setUp(() {
      collector = MetricsCollector();
    });

    tearDown(() {
      collector.dispose();
    });

    test('should record reload metrics', () async {
      collector.recordReload(
        duration: Duration(milliseconds: 150),
        success: true,
        serviceName: 'test-service',
      );

      collector.recordReload(
        duration: Duration(milliseconds: 300),
        success: false,
        serviceName: 'test-service',
      );

      final metrics = await collector.collectMetrics();
      expect(metrics['totalReloads'], equals(2));
      expect(metrics['successfulReloads'], equals(1));
      expect(metrics['failedReloads'], equals(1));
    });

    test('should calculate average reload time', () async {
      collector.recordReload(
        duration: Duration(milliseconds: 100),
        success: true,
      );
      collector.recordReload(
        duration: Duration(milliseconds: 200),
        success: true,
      );

      final metrics = await collector.collectMetrics();
      expect(metrics['averageReloadTime'], equals(150.0));
    });

    test('should track uptime', () async {
      final initialUptime = collector.getUptime();
      await Future.delayed(Duration(seconds: 1)); // Increase delay
      final laterUptime = collector.getUptime();

      expect(laterUptime, greaterThan(initialUptime));
    });
    test('should collect comprehensive metrics', () async {
      final metrics = await collector.collectMetrics();

      expect(metrics, containsPair('uptime', isA<int>()));
      expect(metrics, containsPair('totalReloads', isA<int>()));
      expect(metrics, containsPair('successfulReloads', isA<int>()));
      expect(metrics, containsPair('failedReloads', isA<int>()));
      expect(metrics, containsPair('successRate', isA<String>()));
      expect(metrics, containsPair('averageReloadTime', isA<double>()));
      expect(metrics, containsPair('memoryUsage', isA<int>()));
      expect(metrics, containsPair('platformInfo', isA<Map>()));
      expect(metrics, containsPair('timestamp', isA<String>()));
    });
  });

  group('ReloadHistory', () {
    late ReloadHistory history;

    setUp(() {
      history = ReloadHistory();
    });

    test('should add and retrieve reload events', () {
      history.addEvent(
        serviceName: 'service1',
        type: 'hot_reload',
        duration: Duration(milliseconds: 100),
        changedFiles: ['lib/main.dart'],
      );

      history.addEvent(
        serviceName: 'service2',
        type: 'hot_restart',
        duration: Duration(milliseconds: 500),
        error: 'Compilation error',
      );

      final events = history.getRecentEvents(limit: 10);
      expect(events.length, equals(2));
      expect(events[0]['serviceName'], equals('service2')); // Most recent first
      expect(events[1]['serviceName'], equals('service1'));
    });

    test('should generate statistics', () {
      history.addEvent(
        serviceName: 'service1',
        type: 'hot_reload',
        duration: Duration(milliseconds: 100),
      );

      history.addEvent(
        serviceName: 'service1',
        type: 'failed',
        duration: Duration(milliseconds: 50),
        error: 'Test error',
      );

      final stats = history.getStatistics();
      expect(stats['totalEvents'], equals(2));
      expect(stats['successfulReloads'], equals(1));
      expect(stats['failedReloads'], equals(1));
      expect(stats['successRate'], equals(50.0));
      expect(stats['averageDuration'], equals(75.0));
    });

    test('should filter events by service', () {
      history.addEvent(
        serviceName: 'service1',
        type: 'hot_reload',
        duration: Duration(milliseconds: 100),
      );

      history.addEvent(
        serviceName: 'service2',
        type: 'hot_restart',
        duration: Duration(milliseconds: 200),
      );

      final service1Events = history.getEventsForService('service1');
      expect(service1Events.length, equals(1));
      expect(service1Events[0]['serviceName'], equals('service1'));
    });

    test('should limit event history for memory efficiency', () {
      // Add more than max events
      for (int i = 0; i < 1100; i++) {
        history.addEvent(
          serviceName: 'service$i',
          type: 'hot_reload',
          duration: Duration(milliseconds: 100),
        );
      }

      // Should maintain only the maximum number of events
      expect(history.totalEvents, equals(1000));
    });

    test('should filter events by time range', () async {
      history.addEvent(
        serviceName: 'service1',
        type: 'hot_reload',
        duration: Duration(milliseconds: 100),
      );

      await Future.delayed(Duration(milliseconds: 10));

      history.addEvent(
        serviceName: 'service2',
        type: 'hot_restart',
        duration: Duration(milliseconds: 200),
      );

      final recentEvents =
          history.getEventsInTimeRange(Duration(milliseconds: 5));
      expect(recentEvents.length, equals(1));
      expect(recentEvents[0]['serviceName'], equals('service2'));
    });

    test('should provide service performance breakdown', () {
      history.addEvent(
        serviceName: 'api',
        type: 'hot_reload',
        duration: Duration(milliseconds: 100),
      );

      history.addEvent(
        serviceName: 'api',
        type: 'hot_restart',
        duration: Duration(milliseconds: 300),
      );

      history.addEvent(
        serviceName: 'web',
        type: 'hot_reload',
        duration: Duration(milliseconds: 150),
      );

      final stats = history.getStatistics();
      final breakdown =
          stats['serviceBreakdown'] as Map<String, Map<String, dynamic>>;

      expect(breakdown.containsKey('api'), isTrue);
      expect(breakdown.containsKey('web'), isTrue);
      expect(breakdown['api']!['total'], equals(2));
      expect(breakdown['web']!['total'], equals(1));
      expect(breakdown['api']!['averageDuration'], equals(200.0));
      expect(breakdown['web']!['averageDuration'], equals(150.0));
    });
  });
}
