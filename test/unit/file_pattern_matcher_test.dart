import 'package:test/test.dart';
import 'package:utopia_hotreload/src/file_pattern_matcher.dart';

void main() {
  group('FilePattern', () {
    test('should create include pattern', () {
      const pattern = FilePattern.include('**/*.dart', priority: 5);

      expect(pattern.pattern, equals('**/*.dart'));
      expect(pattern.include, isTrue);
      expect(pattern.priority, equals(5));
      expect(pattern.type, equals(PatternType.glob));
    });

    test('should create exclude pattern', () {
      const pattern = FilePattern.exclude('.git/**', priority: 10);

      expect(pattern.pattern, equals('.git/**'));
      expect(pattern.include, isFalse);
      expect(pattern.priority, equals(10));
      expect(pattern.type, equals(PatternType.glob));
    });

    test('should support different pattern types', () {
      const globPattern =
          FilePattern(pattern: '**/*.dart', type: PatternType.glob);
      const regexPattern =
          FilePattern(pattern: r'.*\.dart$', type: PatternType.regex);
      const simplePattern =
          FilePattern(pattern: '.dart', type: PatternType.simple);
      const extPattern =
          FilePattern(pattern: '.dart', type: PatternType.extension);

      expect(globPattern.type, equals(PatternType.glob));
      expect(regexPattern.type, equals(PatternType.regex));
      expect(simplePattern.type, equals(PatternType.simple));
      expect(extPattern.type, equals(PatternType.extension));
    });

    test('should implement equality correctly', () {
      const pattern1 = FilePattern.include('**/*.dart', priority: 5);
      const pattern2 = FilePattern.include('**/*.dart', priority: 5);
      const pattern3 = FilePattern.include('**/*.yaml', priority: 5);

      expect(pattern1, equals(pattern2));
      expect(pattern1, isNot(equals(pattern3)));
    });

    test('should provide meaningful toString', () {
      const pattern = FilePattern.include('**/*.dart', priority: 5);

      expect(pattern.toString(), contains('include'));
      expect(pattern.toString(), contains('**/*.dart'));
      expect(pattern.toString(), contains('glob'));
      expect(pattern.toString(), contains('5'));
    });
  });

  group('PatternPresets', () {
    test('should provide dart project patterns', () {
      final patterns = PatternPresets.dartProject;

      expect(patterns, isNotEmpty);
      expect(patterns.any((p) => p.pattern == '**/*.dart'), isTrue);
      expect(patterns.any((p) => p.pattern == '**/pubspec.yaml'), isTrue);
      expect(patterns.any((p) => p.pattern == '.dart_tool/**'), isTrue);
    });

    test('should provide web project patterns', () {
      final patterns = PatternPresets.webProject;

      expect(patterns, isNotEmpty);
      expect(patterns.any((p) => p.pattern == '**/*.dart'), isTrue);
      expect(patterns.any((p) => p.pattern == '**/*.html'), isTrue);
      expect(patterns.any((p) => p.pattern == '**/*.css'), isTrue);
      expect(patterns.any((p) => p.pattern == '**/*.js'), isTrue);
    });

    test('should provide flutter project patterns', () {
      final patterns = PatternPresets.flutterProject;

      expect(patterns, isNotEmpty);
      expect(patterns.any((p) => p.pattern == '**/*.dart'), isTrue);
      expect(patterns.any((p) => p.pattern == 'android/**/*.gradle'), isTrue);
      expect(patterns.any((p) => p.pattern == 'ios/**/*.plist'), isTrue);
    });

    test('should provide test-only patterns', () {
      final patterns = PatternPresets.testOnly;

      expect(patterns, isNotEmpty);
      expect(patterns.any((p) => p.pattern == 'test/**/*_test.dart'), isTrue);
      expect(patterns.any((p) => p.pattern == '**/*_test.dart'), isTrue);
    });

    test('should provide config-only patterns', () {
      final patterns = PatternPresets.configOnly;

      expect(patterns, isNotEmpty);
      expect(patterns.any((p) => p.pattern == '**/pubspec.yaml'), isTrue);
      expect(patterns.any((p) => p.pattern == '**/.gitignore'), isTrue);
      expect(patterns.any((p) => p.pattern == '**/*.env'), isTrue);
    });

    test('should get patterns by name', () {
      final dartPatterns = PatternPresets.getByName('dart-project');
      final webPatterns = PatternPresets.getByName('web-project');
      final flutterPatterns = PatternPresets.getByName('flutter-project');

      expect(dartPatterns, equals(PatternPresets.dartProject));
      expect(webPatterns, equals(PatternPresets.webProject));
      expect(flutterPatterns, equals(PatternPresets.flutterProject));
    });

    test('should support case-insensitive names', () {
      final patterns1 = PatternPresets.getByName('DART-PROJECT');
      final patterns2 = PatternPresets.getByName('dart');
      final patterns3 = PatternPresets.getByName('Dart-Project');

      expect(patterns1, equals(PatternPresets.dartProject));
      expect(patterns2, equals(PatternPresets.dartProject));
      expect(patterns3, equals(PatternPresets.dartProject));
    });

    test('should throw on unknown preset name', () {
      expect(() => PatternPresets.getByName('unknown-preset'),
          throwsArgumentError);
    });

    test('should list available presets', () {
      final presets = PatternPresets.availablePresets;

      expect(presets, contains('dart-project'));
      expect(presets, contains('web-project'));
      expect(presets, contains('flutter-project'));
      expect(presets, contains('test-only'));
      expect(presets, contains('config-only'));
    });
  });

  group('FilePatternMatcher', () {
    group('basic pattern matching', () {
      test('should match simple glob patterns', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
          const FilePattern.exclude('**/*_test.dart'),
        ]);

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('lib/utils/helper.dart'), isTrue);
        expect(matcher.matches('test/main_test.dart'), isFalse);
        expect(matcher.matches('lib/main.py'), isFalse);
      });

      test('should handle priority correctly', () {
        final matcher = FilePatternMatcher([
          const FilePattern.exclude('**/*.dart', priority: 1),
          const FilePattern.include('lib/**/*.dart', priority: 10),
        ]);

        // Higher priority include should override lower priority exclude
        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('test/main.dart'), isFalse);
      });

      test('should handle regex patterns', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include(r'.*\.dart$', type: PatternType.regex),
          const FilePattern.exclude(r'.*_test\.dart$', type: PatternType.regex),
        ]);

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('lib/main_test.dart'), isFalse);
        expect(matcher.matches('lib/main.py'), isFalse);
      });

      test('should handle simple string patterns', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('.dart', type: PatternType.simple),
          const FilePattern.exclude('_test', type: PatternType.simple),
        ]);

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('lib/main_test.dart'), isFalse);
        expect(matcher.matches('lib/main.py'), isFalse);
      });

      test('should handle extension patterns', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('.dart', type: PatternType.extension),
          const FilePattern.include('dart', type: PatternType.extension),
        ]);

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('lib/main.py'), isFalse);
        expect(matcher.matches('lib/main'), isFalse);
      });
    });

    group('glob pattern conversion', () {
      test('should convert simple globs', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('*.dart'),
        ]);

        expect(matcher.matches('main.dart'), isTrue);
        expect(matcher.matches('lib/main.dart'),
            isFalse); // single * doesn't cross directories
      });

      test('should convert double-star globs', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
        ]);

        expect(matcher.matches('main.dart'), isTrue);
        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('lib/utils/main.dart'), isTrue);
      });

      test('should handle brace expansion', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.{dart,yaml}'),
        ]);

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('pubspec.yaml'), isTrue);
        expect(matcher.matches('lib/main.py'), isFalse);
      });

      test('should handle question mark wildcards', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('lib/?.dart'),
        ]);

        expect(matcher.matches('lib/a.dart'), isTrue);
        expect(
            matcher.matches('lib/main.dart'), isFalse); // ? matches single char
      });
    });

    group('factory constructors', () {
      test('should create from preset', () {
        final matcher = FilePatternMatcher.fromPreset('dart-project');

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('pubspec.yaml'), isTrue);
        expect(matcher.matches('.dart_tool/package_config.json'), isFalse);
      });

      test('should create from multiple presets', () {
        final matcher =
            FilePatternMatcher.fromPresets(['dart-project', 'web-project']);

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('web/index.html'), isTrue);
        expect(matcher.matches('web/style.css'), isTrue);
      });

      test('should create custom matcher', () {
        final matcher = FilePatternMatcher.custom(
          patterns: [
            const FilePattern.include('**/*.custom'),
          ],
          presets: ['dart-project'],
        );

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('lib/config.custom'), isTrue);
        expect(matcher.matches('lib/main.py'), isFalse);
      });
    });

    group('debugging and introspection', () {
      test('should return matching patterns', () {
        final patterns = [
          const FilePattern.include('**/*.dart', description: 'Dart files'),
          const FilePattern.exclude('**/*_test.dart',
              description: 'Test files'),
        ];
        final matcher = FilePatternMatcher(patterns);

        final matches = matcher.getMatchingPatterns('lib/main.dart');
        expect(matches, hasLength(1));
        expect(matches.first.description, equals('Dart files'));

        final testMatches = matcher.getMatchingPatterns('lib/main_test.dart');
        expect(
            testMatches, hasLength(2)); // Both patterns match, but exclude wins
      });

      test('should provide pattern count', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
          const FilePattern.exclude('**/*_test.dart'),
        ]);

        expect(matcher.patternCount, equals(2));
      });

      test('should provide all patterns', () {
        final patterns = [
          const FilePattern.include('**/*.dart'),
          const FilePattern.exclude('**/*_test.dart'),
        ];
        final matcher = FilePatternMatcher(patterns);

        expect(matcher.patterns, hasLength(2));
        expect(matcher.patterns, containsAll(patterns));
      });

      test('should provide meaningful toString', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
          const FilePattern.exclude('**/*_test.dart'),
        ]);

        expect(matcher.toString(), contains('FilePatternMatcher'));
        expect(matcher.toString(), contains('2 patterns'));
      });
    });

    group('edge cases', () {
      test('should handle empty pattern list', () {
        final matcher = FilePatternMatcher([]);

        expect(matcher.matches('anything.dart'), isFalse);
      });

      test('should handle path normalization', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('lib/**/*.dart'),
        ]);

        expect(matcher.matches('lib/main.dart'), isTrue);
        expect(matcher.matches('lib\\main.dart'), isTrue); // Windows path
        expect(matcher.matches('./lib/main.dart'), isTrue); // Relative path
      });

      test('should default to exclude when no patterns match', () {
        final matcher = FilePatternMatcher([
          const FilePattern.include('**/*.dart'),
        ]);

        expect(matcher.matches('lib/main.py'), isFalse);
        expect(matcher.matches('readme.md'), isFalse);
      });
    });
  });
}
