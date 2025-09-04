import 'package:test/test.dart';
import 'package:utopia_hotreload/src/hot_reload_manager.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';

void main() {
  group('HotReloadManager', () {
    test('can be constructed', () {
      final manager = HotReloadManager(
        script: () async {},
        config: const ReloadConfig(),
      );
      expect(manager, isA<HotReloadManager>());
    });
  });
}
