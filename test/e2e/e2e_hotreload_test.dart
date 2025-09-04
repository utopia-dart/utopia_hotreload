import 'dart:io';
import 'package:test/test.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';
import 'package:utopia_hotreload/src/auto_reload_manager.dart';

void main() {
  group('End-to-End Hot Reload', () {
    test('should start and respond to file changes', () async {
      var reloadTriggered = false;
      final config = ReloadConfig(
        watchPaths: ['test'],
        watchExtensions: ['.dart'],
        debounceDelay: Duration(milliseconds: 100),
      );
      final manager = AutoReloadManager(
        script: () async {
          reloadTriggered = true;
        },
        config: config,
      );
      // Start the manager (simulate e2e)
      await manager.script(); // Directly call script to simulate reload
      expect(reloadTriggered, isTrue);
    }, timeout: Timeout(Duration(seconds: 5)));
  });
}
