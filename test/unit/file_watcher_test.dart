import 'dart:io';
import 'package:test/test.dart';
import 'package:utopia_hotreload/src/file_watcher.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';

void main() {
  group('HotReloadFileWatcher', () {
    test('should ignore files by pattern', () async {
      final config = ReloadConfig(ignorePatterns: ['.git/', 'build/']);
      final watcher = HotReloadFileWatcher(config);
      expect(watcher.config.ignorePatterns, contains('.git/'));
      expect(watcher.config.ignorePatterns, contains('build/'));
    });

    test('should watch correct extensions', () async {
      final config = ReloadConfig(watchExtensions: ['.dart', '.yaml']);
      final watcher = HotReloadFileWatcher(config);
      expect(watcher.config.watchExtensions, contains('.dart'));
      expect(watcher.config.watchExtensions, contains('.yaml'));
    });

    // Integration test for file watching would require filesystem events
    // and is best covered in e2e tests
  });
}
