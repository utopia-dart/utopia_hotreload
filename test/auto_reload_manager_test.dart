import 'package:test/test.dart';
import 'package:utopia_hotreload/src/auto_reload_manager.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';

void main() {
  group('AutoReloadManager', () {
    test('can be constructed', () {
      final manager = AutoReloadManager(
        script: () async {},
        config: const ReloadConfig(),
      );
      expect(manager, isA<AutoReloadManager>());
    });
  });
}
