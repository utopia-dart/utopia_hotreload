import 'package:test/test.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';

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
    test('default values', () {
      const config = ReloadConfig();
      expect(config.mode, equals(ReloadMode.auto));
      expect(config.watchPaths, equals(['lib']));
      expect(config.watchExtensions, equals(['.dart']));
      expect(config.ignorePatterns, contains('.git/'));
      expect(config.debounceDelay, equals(Duration(milliseconds: 500)));
      expect(config.verbose, isFalse);
      expect(config.childVmServicePort, isNull);
    });

    test('custom values', () {
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
}
