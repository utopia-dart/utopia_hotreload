import 'package:test/test.dart';
import 'package:utopia_hotreload/src/reload_config.dart';
import 'package:utopia_hotreload/src/file_pattern_matcher.dart';

void main() {
  group('ReloadMode', () {
    test('enum values', () {
      expect(ReloadMode.values.length, equals(3));
      expect(ReloadMode.values, contains(ReloadMode.hotReload));
      expect(ReloadMode.values, contains(ReloadMode.hotRestart));
      expect(ReloadMode.values, contains(ReloadMode.auto));
    });
  });

  group('ReloadConfig', () {
    group('basic configuration', () {
      test('should create default config', () {
        const config = ReloadConfig();

        expect(config.mode, equals(ReloadMode.auto));
        expect(config.watchPaths, equals(['lib']));
        expect(config.watchExtensions, equals(['.dart']));
        expect(config.ignorePatterns, contains('.git/'));
        expect(config.debounceDelay, equals(Duration(milliseconds: 500)));
        expect(config.verbose, isFalse);
        expect(config.childVmServicePort, isNull);
      });

      test('should create config with custom values', () {
        const config = ReloadConfig(
          mode: ReloadMode.hotRestart,
          watchPaths: ['lib', 'bin'],
          watchExtensions: ['.dart', '.yaml'],
          ignorePatterns: ['.git/', 'build/'],
          debounceDelay: Duration(seconds: 1),
          verbose: true,
          childVmServicePort: 12345,
        );

        expect(config.mode, equals(ReloadMode.hotRestart));
        expect(config.watchPaths, equals(['lib', 'bin']));
        expect(config.watchExtensions, equals(['.dart', '.yaml']));
        expect(config.ignorePatterns, equals(['.git/', 'build/']));
        expect(config.debounceDelay, equals(Duration(seconds: 1)));
        expect(config.verbose, isTrue);
        expect(config.childVmServicePort, equals(12345));
      });
    });

    group('pattern-based configuration', () {
      test('should create config with patterns', () {
        final config = ReloadConfig.withPatterns(
          watchPaths: ['lib'],
          presets: ['dart-project'],
          patterns: [
            const FilePattern.include('**/*.env'),
          ],
        );

        expect(config.patternPresets, equals(['dart-project']));
        expect(config.customPatterns, hasLength(1));
        expect(config.patternMatcher, isNotNull);
      });

      test('should create config with custom matcher', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
        ]);

        final config = ReloadConfig.withMatcher(
          patternMatcher: matcher,
        );

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

        final config = ReloadConfig.withMatcher(
          patternMatcher: matcher,
        );

        expect(config.effectivePatternMatcher, equals(matcher));
      });

      test('should create matcher from presets and patterns', () {
        final config = ReloadConfig.withPatterns(
          presets: ['dart-project'],
          patterns: [
            const FilePattern.include('**/*.env'),
          ],
        );

        final matcher = config.effectivePatternMatcher;
        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('config.env'), isTrue);
      });

      test('should fallback to extension-based matcher', () {
        const config = ReloadConfig(
          watchExtensions: ['.dart', '.yaml'],
          ignorePatterns: ['.git/', '*.log'],
        );

        final matcher = config.effectivePatternMatcher;
        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('pubspec.yaml'), isTrue);
        expect(matcher.matches('.git/config'), isFalse);
        expect(matcher.matches('debug.log'), isFalse);
      });

      test('should handle empty configuration', () {
        const config = ReloadConfig(
          watchExtensions: [],
          ignorePatterns: [],
        );

        final matcher = config.effectivePatternMatcher;
        expect(matcher.matches('anything.dart'), isFalse);
      });
    });
  });
}
