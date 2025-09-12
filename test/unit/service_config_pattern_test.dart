import 'package:test/test.dart';
import 'package:utopia_hotreload/src/service_config.dart';
import 'package:utopia_hotreload/src/file_pattern_matcher.dart';

void main() {
  Future<void> dummyScript() async {}

  group('ServiceConfig', () {
    group('basic configuration', () {
      test('should create basic service config', () {
        final config = ServiceConfig(
          name: 'test-service',
          script: dummyScript,
          displayName: 'Test Service',
          watchPaths: ['lib', 'bin'],
          priority: 10,
        );

        expect(config.name, equals('test-service'));
        expect(config.effectiveDisplayName, equals('Test Service'));
        expect(config.watchPaths, equals(['lib', 'bin']));
        expect(config.priority, equals(10));
        expect(config.autoStart, isTrue);
      });

      test('should use name as display name when not provided', () {
        final config = ServiceConfig(
          name: 'api-server',
          script: dummyScript,
        );

        expect(config.effectiveDisplayName, equals('api-server'));
      });
    });

    group('pattern-based configuration', () {
      test('should create service with patterns', () {
        final config = ServiceConfig.withPatterns(
          name: 'web-service',
          script: dummyScript,
          presets: ['web-project'],
          patterns: [
            const FilePattern.include('**/*.env'),
          ],
        );

        expect(config.name, equals('web-service'));
        expect(config.patternPresets, equals(['web-project']));
        expect(config.customPatterns, hasLength(1));
        expect(config.patternMatcher, isNotNull);
      });

      test('should create service with custom matcher', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
        ]);

        final config = ServiceConfig.withMatcher(
          name: 'dart-service',
          script: dummyScript,
          patternMatcher: matcher,
        );

        expect(config.name, equals('dart-service'));
        expect(config.patternMatcher, equals(matcher));
        expect(config.patternPresets, isEmpty);
        expect(config.customPatterns, isEmpty);
      });
    });

    group('effective pattern matcher', () {
      test('should return configured pattern matcher', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
        ]);

        final config = ServiceConfig.withMatcher(
          name: 'test',
          script: dummyScript,
          patternMatcher: matcher,
        );

        expect(config.effectivePatternMatcher, equals(matcher));
      });

      test('should create matcher from presets and patterns', () {
        final config = ServiceConfig.withPatterns(
          name: 'test',
          script: dummyScript,
          presets: ['dart-project'],
          patterns: [
            const FilePattern.include('**/*.env'),
          ],
        );

        final matcher = config.effectivePatternMatcher;
        expect(matcher, isNotNull);
        expect(matcher!.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('root.env'), isTrue); // .env files at root level
      });

      test('should return null for legacy extension-based filtering', () {
        final config = ServiceConfig(
          name: 'test',
          script: dummyScript,
          watchExtensions: ['.dart'],
        );

        expect(config.effectivePatternMatcher, isNull);
      });
    });

    group('copyWith method', () {
      test('should copy basic properties', () {
        final original = ServiceConfig(
          name: 'original',
          script: dummyScript,
          displayName: 'Original Service',
          priority: 5,
        );

        final copied = original.copyWith(
          displayName: 'Updated Service',
          priority: 10,
        );

        expect(copied.name, equals('original'));
        expect(copied.effectiveDisplayName, equals('Updated Service'));
        expect(copied.priority, equals(10));
        expect(copied.script, equals(dummyScript));
      });

      test('should copy pattern properties', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
        ]);

        final original = ServiceConfig.withMatcher(
          name: 'original',
          script: dummyScript,
          patternMatcher: matcher,
        );

        final newMatcher = FilePatternMatcher([
          const FilePattern.include('**/*.yaml'),
        ]);

        final copied = original.copyWith(
          patternMatcher: newMatcher,
        );

        expect(copied.patternMatcher, equals(newMatcher));
        expect(copied.name, equals('original'));
      });
    });

    group('equality and hashCode', () {
      test('should be equal based on name', () {
        final config1 = ServiceConfig(
          name: 'service1',
          script: dummyScript,
          priority: 5,
        );

        final config2 = ServiceConfig(
          name: 'service1',
          script: dummyScript,
          priority: 10, // Different priority
        );

        final config3 = ServiceConfig(
          name: 'service2',
          script: dummyScript,
        );

        expect(config1, equals(config2));
        expect(config1, isNot(equals(config3)));
        expect(config1.hashCode, equals(config2.hashCode));
      });
    });

    group('toString method', () {
      test('should provide meaningful string representation', () {
        final config = ServiceConfig(
          name: 'test-service',
          script: dummyScript,
          displayName: 'Test Service',
          priority: 10,
          autoStart: false,
        );

        final str = config.toString();
        expect(str, contains('test-service'));
        expect(str, contains('Test Service'));
        expect(str, contains('10'));
        expect(str, contains('false'));
      });
    });
  });
}
