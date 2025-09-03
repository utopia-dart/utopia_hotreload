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
  });
}
