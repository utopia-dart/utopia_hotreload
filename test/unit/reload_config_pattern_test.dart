import 'package:test/test.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';
import 'package:utopia_hotreload/src/file_pattern_matcher.dart';

void main() {
  group('ReloadConfig', () {
    group('basic configuration', () {
      test('should create default config', () {
        const config = ReloadConfig();

        expect(config.mode, equals(ReloadMode.auto));
        expect(config.watchPaths, equals(['lib']));
        expect(config.watchExtensions, equals(['.dart']));
        expect(config.debounceDelay, equals(Duration(milliseconds: 500)));
        expect(config.verbose, isFalse);
      });

      test('should create config with custom values', () {
        const config = ReloadConfig(
          mode: ReloadMode.hotReload,
          watchPaths: ['lib', 'bin'],
          watchExtensions: ['.dart', '.yaml'],
          debounceDelay: Duration(milliseconds: 200),
          verbose: true,
        );

        expect(config.mode, equals(ReloadMode.hotReload));
        expect(config.watchPaths, equals(['lib', 'bin']));
        expect(config.watchExtensions, equals(['.dart', '.yaml']));
        expect(config.debounceDelay, equals(Duration(milliseconds: 200)));
        expect(config.verbose, isTrue);
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
