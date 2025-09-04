import 'package:test/test.dart';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() {
  group('Utopia Hot Reload', () {
    test('can import public API', () {
      expect(ReloadMode.values, isNotEmpty);
      expect(ReloadMode.hotReload, equals(ReloadMode.hotReload));
      expect(ReloadMode.hotRestart, equals(ReloadMode.hotRestart));
      expect(ReloadMode.auto, equals(ReloadMode.auto));
    });

    test('DeveloperTools class exists', () {
      expect(DeveloperTools, isNotNull);
    });

    test('ReloadMode enum has all expected values', () {
      expect(ReloadMode.values.length, equals(3));
      expect(ReloadMode.values, contains(ReloadMode.hotReload));
      expect(ReloadMode.values, contains(ReloadMode.hotRestart));
      expect(ReloadMode.values, contains(ReloadMode.auto));
    });

    // Integration test would require spawning processes
    // For now, we just test that the API is accessible
    test('DeveloperTools.start method signature is correct', () {
      // This test ensures the API doesn't break
      // We can't actually run it without spawning processes
      expect(DeveloperTools.start, isA<Function>());
    });
  });
}
