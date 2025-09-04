import 'package:test/test.dart';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() {
  group('Utopia Hot Reload', () {
    test('can import all components', () {
      expect(ReloadMode.values, isNotEmpty);
      expect(ReloadMode.hotReload, equals(ReloadMode.hotReload));
      expect(ReloadMode.hotRestart, equals(ReloadMode.hotRestart));
      expect(ReloadMode.auto, equals(ReloadMode.auto));
    });

    test('DeveloperTools exists', () {
      expect(DeveloperTools, isNotNull);
    });

    test('HotReloadManager exists', () {
      expect(HotReloadManager, isNotNull);
    });

    test('HotRestartManager exists', () {
      expect(HotRestartManager, isNotNull);
    });

    test('AutoReloadManager exists', () {
      expect(AutoReloadManager, isNotNull);
    });

    test('HotReloadFileWatcher exists', () {
      expect(HotReloadFileWatcher, isNotNull);
    });

    test('ReloadConfig has correct defaults', () {
      const config = ReloadConfig();
      expect(config.mode, equals(ReloadMode.auto));
      expect(config.watchPaths, equals(['lib']));
      expect(config.watchExtensions, equals(['.dart']));
      expect(config.debounceDelay, equals(Duration(milliseconds: 500)));
      expect(config.verbose, equals(false));
      expect(config.ignorePatterns, contains('.git/'));
      expect(config.ignorePatterns, contains('.dart_tool/'));
    });

    test('ReloadConfig can be customized', () {
      const config = ReloadConfig(
        mode: ReloadMode.hotRestart,
        watchPaths: ['lib', 'bin'],
        watchExtensions: ['.dart', '.yaml'],
        debounceDelay: Duration(milliseconds: 1000),
        verbose: true,
      );

      expect(config.mode, equals(ReloadMode.hotRestart));
      expect(config.watchPaths, equals(['lib', 'bin']));
      expect(config.watchExtensions, equals(['.dart', '.yaml']));
      expect(config.debounceDelay, equals(Duration(milliseconds: 1000)));
      expect(config.verbose, equals(true));
    });
  });
}
