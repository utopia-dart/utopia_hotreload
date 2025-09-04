import 'package:test/test.dart';
import 'package:utopia_hotreload/src/hot_restart_manager.dart';
import 'package:utopia_hotreload/src/reload_mode.dart';

void main() {
  group('HotRestartManager', () {
    test('can be constructed', () {
      final manager = HotRestartManager(
        script: () async {},
        config: const ReloadConfig(),
      );
      expect(manager, isA<HotRestartManager>());
    });
  });
}
