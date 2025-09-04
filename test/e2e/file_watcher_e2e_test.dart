import 'dart:io';
import 'dart:async';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:utopia_hotreload/src/file_watcher.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';

void main() {
  group('E2E File Watcher Tests', () {
    late Directory tempDir;
    late File watchedFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_watcher_e2e_');
      watchedFile = File(path.join(tempDir.path, 'watched.dart'));
      await watchedFile.writeAsString('// Initial content\nvoid main() {}\n');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('file watcher should detect real file changes', () async {
      final config = ReloadConfig(
        watchPaths: [tempDir.path],
        watchExtensions: ['.dart'],
        debounceDelay: Duration(milliseconds: 100),
        verbose: true,
      );

      final watcher = HotReloadFileWatcher(config);
      final changeCompleter = Completer<String>();
      String? changedFilePath;

      // Start watching
      await watcher.start((filePath) {
        changedFilePath = filePath;
        if (!changeCompleter.isCompleted) {
          changeCompleter.complete(filePath);
        }
      });

      // Wait a moment for watcher to initialize
      await Future.delayed(Duration(milliseconds: 200));

      // Modify the file
      await watchedFile.writeAsString(
          '// Modified content\nvoid main() { print("hello"); }\n');

      // Wait for change detection
      final detectedPath = await changeCompleter.future.timeout(
        Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
            'File change not detected', Duration(seconds: 5)),
      );

      expect(detectedPath, equals(watchedFile.path));
      expect(changedFilePath, equals(watchedFile.path));

      // Cleanup
      await watcher.stop();
    });

    test('file watcher should ignore files with wrong extensions', () async {
      final config = ReloadConfig(
        watchPaths: [tempDir.path],
        watchExtensions: ['.dart'], // Only watch .dart files
        debounceDelay: Duration(milliseconds: 100),
      );

      final watcher = HotReloadFileWatcher(config);
      final changeCompleter = Completer<String>();
      bool changeDetected = false;

      await watcher.start((filePath) {
        changeDetected = true;
        if (!changeCompleter.isCompleted) {
          changeCompleter.complete(filePath);
        }
      });

      await Future.delayed(Duration(milliseconds: 200));

      // Create a .txt file (should be ignored)
      final ignoredFile = File(path.join(tempDir.path, 'ignored.txt'));
      await ignoredFile.writeAsString('This should be ignored');

      // Wait to see if any change is detected (it shouldn't be)
      try {
        await changeCompleter.future.timeout(Duration(milliseconds: 500));
        fail('Change should not have been detected for .txt file');
      } on TimeoutException {
        // This is expected - no change should be detected
        expect(changeDetected, isFalse);
      }

      await watcher.stop();
    });

    test('file watcher should respect ignore patterns', () async {
      // Create a .git subdirectory
      final gitDir = Directory(path.join(tempDir.path, '.git'));
      await gitDir.create();

      final config = ReloadConfig(
        watchPaths: [tempDir.path],
        watchExtensions: ['.dart'],
        ignorePatterns: ['.git/'],
        debounceDelay: Duration(milliseconds: 100),
      );

      final watcher = HotReloadFileWatcher(config);
      final changeCompleter = Completer<String>();
      bool changeDetected = false;

      await watcher.start((filePath) {
        changeDetected = true;
        if (!changeCompleter.isCompleted) {
          changeCompleter.complete(filePath);
        }
      });

      await Future.delayed(Duration(milliseconds: 200));

      // Create a file in .git directory (should be ignored)
      final gitFile = File(path.join(gitDir.path, 'config.dart'));
      await gitFile.writeAsString('void main() {}');

      // Wait to see if any change is detected (it shouldn't be)
      try {
        await changeCompleter.future.timeout(Duration(seconds: 2));
        fail('Change should not have been detected for file in .git directory');
      } on TimeoutException {
        // This is expected - no change should be detected
        expect(changeDetected, isFalse);
      }

      await watcher.stop();
    });
  });
}
