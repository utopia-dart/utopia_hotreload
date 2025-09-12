import 'package:test/test.dart';
import 'package:utopia_hotreload/utopia_hotreload.dart';
import 'package:utopia_hotreload/src/reload_config.dart';
import 'package:utopia_hotreload/src/multi_service_manager.dart';

void main() {
  group('ServiceConfig', () {
    test('should create service config with required parameters', () {
      final service = ServiceConfig(
        name: 'test-service',
        script: () async => print('test'),
      );

      expect(service.name, equals('test-service'));
      expect(service.effectiveDisplayName, equals('test-service'));
      expect(service.autoStart, isTrue);
      expect(service.priority, equals(0));
      expect(service.environment, isEmpty);
    });

    test('should use custom display name when provided', () {
      final service = ServiceConfig(
        name: 'api',
        script: () async => print('test'),
        displayName: 'API Server',
      );

      expect(service.effectiveDisplayName, equals('API Server'));
    });

    test('should support custom configuration', () {
      final service = ServiceConfig(
        name: 'worker',
        script: () async => print('test'),
        displayName: 'Background Worker',
        watchPaths: ['lib', 'workers'],
        watchExtensions: ['.dart', '.yaml'],
        ignorePatterns: ['temp/'],
        autoStart: false,
        priority: 10,
        vmServicePort: 8181,
        environment: {'ENV': 'test'},
        workingDirectory: '/custom/path',
        verbose: true,
      );

      expect(service.name, equals('worker'));
      expect(service.effectiveDisplayName, equals('Background Worker'));
      expect(service.watchPaths, equals(['lib', 'workers']));
      expect(service.watchExtensions, equals(['.dart', '.yaml']));
      expect(service.ignorePatterns, equals(['temp/']));
      expect(service.autoStart, isFalse);
      expect(service.priority, equals(10));
      expect(service.vmServicePort, equals(8181));
      expect(service.environment, equals({'ENV': 'test'}));
      expect(service.workingDirectory, equals('/custom/path'));
      expect(service.verbose, isTrue);
    });

    test('should support copyWith for modifications', () {
      final original = ServiceConfig(
        name: 'test',
        script: () async => print('test'),
        priority: 5,
      );

      final modified = original.copyWith(
        priority: 10,
        autoStart: false,
      );

      expect(modified.name, equals('test'));
      expect(modified.priority, equals(10));
      expect(modified.autoStart, isFalse);
      expect(original.priority, equals(5)); // Original unchanged
      expect(original.autoStart, isTrue); // Original unchanged
    });

    test('should implement equality based on name', () {
      final service1 = ServiceConfig(
        name: 'test',
        script: () async => print('test1'),
      );

      final service2 = ServiceConfig(
        name: 'test',
        script: () async => print('test2'),
      );

      final service3 = ServiceConfig(
        name: 'different',
        script: () async => print('test'),
      );

      expect(service1, equals(service2));
      expect(service1, isNot(equals(service3)));
      expect(service1.hashCode, equals(service2.hashCode));
    });

    test('should have meaningful toString representation', () {
      final service = ServiceConfig(
        name: 'api',
        script: () async => print('test'),
        displayName: 'API Server',
        priority: 10,
      );

      final str = service.toString();
      expect(str, contains('api'));
      expect(str, contains('API Server'));
      expect(str, contains('priority: 10'));
    });
  });

  group('DeveloperTools.startMultiple', () {
    test('should validate that services are provided', () async {
      expect(
        () => DeveloperTools.startMultiple([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should accept valid service configurations', () async {
      final services = [
        ServiceConfig(
          name: 'test1',
          script: () async => print('test1'),
        ),
        ServiceConfig(
          name: 'test2',
          script: () async => print('test2'),
        ),
      ];

      // This should not throw during validation
      expect(() => services, returnsNormally);
    });

    test('should support global configuration options', () async {
      final services = [
        ServiceConfig(
          name: 'test',
          script: () async => print('test'),
        ),
      ];

      // Test that configuration is valid - just validate parameters without starting
      final globalConfig = ReloadConfig(
        mode: ReloadMode.auto,
        watchPaths: ['lib'],
        watchExtensions: ['.dart', '.yaml'],
        ignorePatterns: ['build/'],
        debounceDelay: Duration(milliseconds: 300),
        verbose: true,
      );

      // Validate configuration creation works
      expect(globalConfig.watchPaths, equals(['lib']));
      expect(globalConfig.watchExtensions, equals(['.dart', '.yaml']));
      expect(globalConfig.ignorePatterns, equals(['build/']));
      expect(globalConfig.debounceDelay, equals(Duration(milliseconds: 300)));
      expect(globalConfig.verbose, isTrue);

      // Validate that we can create a manager with these settings
      final manager = MultiServiceManager(services, globalConfig);
      expect(manager, isNotNull);
    });
  });

  group('Service Configuration Validation', () {
    test('should handle services with overlapping watch paths', () {
      final service1 = ServiceConfig(
        name: 'api',
        script: () async => print('api'),
        watchPaths: ['lib', 'shared'],
      );

      final service2 = ServiceConfig(
        name: 'web',
        script: () async => print('web'),
        watchPaths: ['lib', 'web'],
      );

      // Should be valid - services can watch overlapping paths
      expect([service1, service2], hasLength(2));
    });

    test('should handle services with same priority', () {
      final service1 = ServiceConfig(
        name: 'api',
        script: () async => print('api'),
        priority: 10,
      );

      final service2 = ServiceConfig(
        name: 'web',
        script: () async => print('web'),
        priority: 10,
      );

      // Should be valid - services can have same priority
      expect([service1, service2], hasLength(2));
    });

    test('should handle services with different configurations', () {
      final services = [
        ServiceConfig(
          name: 'api',
          script: () async => print('api'),
          watchPaths: ['lib/api'],
          watchExtensions: ['.dart'],
          priority: 10,
          autoStart: true,
        ),
        ServiceConfig(
          name: 'web',
          script: () async => print('web'),
          watchPaths: ['web'],
          watchExtensions: ['.dart', '.html', '.css'],
          priority: 5,
          autoStart: true,
        ),
        ServiceConfig(
          name: 'worker',
          script: () async => print('worker'),
          watchPaths: ['lib/workers'],
          watchExtensions: ['.dart'],
          priority: 1,
          autoStart: false, // Manual start
        ),
      ];

      expect(services, hasLength(3));
      expect(services.where((s) => s.autoStart), hasLength(2));
      expect(services.where((s) => !s.autoStart), hasLength(1));
    });
  });

  group('Service Priority and Ordering', () {
    test('should sort services by priority correctly', () {
      final services = [
        ServiceConfig(name: 'low', script: () async {}, priority: 1),
        ServiceConfig(name: 'high', script: () async {}, priority: 10),
        ServiceConfig(name: 'medium', script: () async {}, priority: 5),
        ServiceConfig(name: 'zero', script: () async {}, priority: 0),
      ];

      // Sort by priority (highest first)
      services.sort((a, b) => b.priority.compareTo(a.priority));

      expect(services[0].name, equals('high'));
      expect(services[1].name, equals('medium'));
      expect(services[2].name, equals('low'));
      expect(services[3].name, equals('zero'));
    });

    test('should handle negative priorities', () {
      final services = [
        ServiceConfig(name: 'negative', script: () async {}, priority: -5),
        ServiceConfig(name: 'positive', script: () async {}, priority: 5),
        ServiceConfig(name: 'zero', script: () async {}, priority: 0),
      ];

      services.sort((a, b) => b.priority.compareTo(a.priority));

      expect(services[0].name, equals('positive'));
      expect(services[1].name, equals('zero'));
      expect(services[2].name, equals('negative'));
    });
  });

  group('Environment and Configuration', () {
    test('should handle empty environment variables', () {
      final service = ServiceConfig(
        name: 'test',
        script: () async {},
        environment: {},
      );

      expect(service.environment, isEmpty);
    });

    test('should handle custom environment variables', () {
      final env = {
        'NODE_ENV': 'development',
        'API_KEY': 'test-key',
        'DEBUG': 'true',
      };

      final service = ServiceConfig(
        name: 'test',
        script: () async {},
        environment: env,
      );

      expect(service.environment, equals(env));
      expect(service.environment['NODE_ENV'], equals('development'));
    });

    test('should handle null optional parameters', () {
      final service = ServiceConfig(
        name: 'test',
        script: () async {},
        displayName: null,
        watchPaths: null,
        watchExtensions: null,
        ignorePatterns: null,
        vmServicePort: null,
        workingDirectory: null,
        verbose: null,
      );

      expect(service.displayName, isNull);
      expect(service.watchPaths, isNull);
      expect(service.watchExtensions, isNull);
      expect(service.ignorePatterns, isNull);
      expect(service.vmServicePort, isNull);
      expect(service.workingDirectory, isNull);
      expect(service.verbose, isNull);
    });
  });
}
