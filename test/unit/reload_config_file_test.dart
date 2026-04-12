import 'dart:io';

import 'package:test/test.dart';
import 'package:utopia_hotreload/src/reload_config.dart';
import 'package:utopia_hotreload/src/reload_config_file.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hotreload_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String writeTempYaml(String content) {
    final file = File('${tempDir.path}/hotreload.yaml');
    file.writeAsStringSync(content);
    return file.path;
  }

  group('ReloadConfigFile', () {
    group('load', () {
      test('returns null when file does not exist', () {
        final config = ReloadConfigFile.load(
          '${tempDir.path}/nonexistent.yaml',
        );
        expect(config, isNull);
      });

      test('returns null for empty file', () {
        final path = writeTempYaml('');
        final config = ReloadConfigFile.load(path);
        expect(config, isNull);
      });

      test('returns null for whitespace-only file', () {
        final path = writeTempYaml('   \n  \n  ');
        final config = ReloadConfigFile.load(path);
        expect(config, isNull);
      });

      test('throws FormatException for non-map YAML', () {
        final path = writeTempYaml('- item1\n- item2');
        expect(() => ReloadConfigFile.load(path), throwsFormatException);
      });

      test('loads valid full config', () {
        final path = writeTempYaml('''
watch_paths:
  - lib
  - bin
watch_extensions:
  - .dart
  - .yaml
ignore_patterns:
  - .git/
  - build/
mode: hotReload
debounce_ms: 300
verbose: true
vm_service_port: 8181
dashboard:
  enabled: true
  port: 9090
''');
        final config = ReloadConfigFile.load(path);
        expect(config, isNotNull);
        expect(config!.watchPaths, equals(['lib', 'bin']));
        expect(config.watchExtensions, equals(['.dart', '.yaml']));
        expect(config.ignorePatterns, equals(['.git/', 'build/']));
        expect(config.mode, equals(ReloadMode.hotReload));
        expect(config.debounceDelay, equals(Duration(milliseconds: 300)));
        expect(config.verbose, isTrue);
        expect(config.childVmServicePort, equals(8181));
        expect(config.enableDashboard, isTrue);
        expect(config.dashboardPort, equals(9090));
      });

      test('uses defaults when fields are missing', () {
        final path = writeTempYaml('verbose: true\n');
        final config = ReloadConfigFile.load(path);
        expect(config, isNotNull);
        expect(config!.watchPaths, equals(['lib']));
        expect(config.watchExtensions, equals(['.dart']));
        expect(
          config.ignorePatterns,
          equals(['.git/', '.dart_tool/', 'build/', 'pubspec.lock']),
        );
        expect(config.mode, equals(ReloadMode.auto));
        expect(config.debounceDelay, equals(Duration(milliseconds: 500)));
        expect(config.verbose, isTrue);
        expect(config.childVmServicePort, isNull);
        expect(config.enableDashboard, isFalse);
        expect(config.dashboardPort, equals(9000));
      });

      test('parses hotRestart mode', () {
        final path = writeTempYaml('mode: hotRestart\n');
        final config = ReloadConfigFile.load(path);
        expect(config!.mode, equals(ReloadMode.hotRestart));
      });

      test('falls back to auto for unknown mode', () {
        final path = writeTempYaml('mode: unknown\n');
        final config = ReloadConfigFile.load(path);
        expect(config!.mode, equals(ReloadMode.auto));
      });

      test('parses single string as list', () {
        final path = writeTempYaml('watch_paths: src\n');
        final config = ReloadConfigFile.load(path);
        expect(config!.watchPaths, equals(['src']));
      });

      test('supports camelCase field names', () {
        final path = writeTempYaml('''
watchPaths:
  - src
  - bin
watchExtensions:
  - .dart
ignorePatterns:
  - .git/
debounceMs: 200
vmServicePort: 5555
''');
        final config = ReloadConfigFile.load(path);
        expect(config, isNotNull);
        expect(config!.watchPaths, equals(['src', 'bin']));
        expect(config.watchExtensions, equals(['.dart']));
        expect(config.ignorePatterns, equals(['.git/']));
        expect(config.debounceDelay, equals(Duration(milliseconds: 200)));
        expect(config.childVmServicePort, equals(5555));
      });

      test('snake_case takes precedence over camelCase', () {
        final path = writeTempYaml('''
watch_paths:
  - lib
watchPaths:
  - src
''');
        final config = ReloadConfigFile.load(path);
        expect(config!.watchPaths, equals(['lib']));
      });

      test('parses flat dashboard fields', () {
        final path = writeTempYaml('''
enable_dashboard: true
dashboard_port: 8888
''');
        final config = ReloadConfigFile.load(path);
        expect(config!.enableDashboard, isTrue);
        expect(config.dashboardPort, equals(8888));
      });

      test('nested dashboard overrides flat fields', () {
        final path = writeTempYaml('''
enable_dashboard: false
dashboard:
  enabled: true
  port: 7777
''');
        final config = ReloadConfigFile.load(path);
        expect(config!.enableDashboard, isTrue);
        expect(config.dashboardPort, equals(7777));
      });
    });

    group('merge', () {
      test('programmatic values override file config', () {
        final path = writeTempYaml('''
watch_paths:
  - lib
verbose: false
mode: auto
debounce_ms: 500
''');
        final fileConfig = ReloadConfigFile.load(path)!;
        final merged = ReloadConfigFile.merge(
          fileConfig,
          watchPaths: ['src', 'bin'],
          verbose: true,
          mode: ReloadMode.hotReload,
        );

        expect(merged.watchPaths, equals(['src', 'bin']));
        expect(merged.verbose, isTrue);
        expect(merged.mode, equals(ReloadMode.hotReload));
        expect(merged.debounceDelay, equals(Duration(milliseconds: 500)));
      });

      test('null overrides keep file config values', () {
        final path = writeTempYaml('''
watch_paths:
  - lib
  - bin
verbose: true
mode: hotRestart
debounce_ms: 300
''');
        final fileConfig = ReloadConfigFile.load(path)!;
        final merged = ReloadConfigFile.merge(fileConfig);

        expect(merged.watchPaths, equals(['lib', 'bin']));
        expect(merged.verbose, isTrue);
        expect(merged.mode, equals(ReloadMode.hotRestart));
        expect(merged.debounceDelay, equals(Duration(milliseconds: 300)));
      });

      test('merges dashboard settings', () {
        final path = writeTempYaml('''
dashboard:
  enabled: true
  port: 9090
''');
        final fileConfig = ReloadConfigFile.load(path)!;
        final merged = ReloadConfigFile.merge(
          fileConfig,
          dashboardPort: 8080,
        );

        expect(merged.enableDashboard, isTrue);
        expect(merged.dashboardPort, equals(8080));
      });
    });

    group('defaultFileName', () {
      test('is hotreload.yaml', () {
        expect(ReloadConfigFile.defaultFileName, equals('hotreload.yaml'));
      });
    });
  });
}
