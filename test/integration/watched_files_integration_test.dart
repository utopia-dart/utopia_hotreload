import 'package:test/test.dart';
import 'package:utopia_hotreload/src/file_pattern_matcher.dart';
import 'package:utopia_hotreload/src/multi_service_manager.dart';
import 'package:utopia_hotreload/src/service_config.dart';
import 'package:utopia_hotreload/src/reload_config.dart';

void main() {
  group('End-to-End Integration Test', () {
    test('complete watched files flow should work', () async {
      // Test the complete integration
      Future<void> testScript() async {}

      // Create a service with file watching
      final services = [
        ServiceConfig(
          name: 'test-service',
          script: testScript,
          watchPaths: ['lib/', 'test/'],
          customPatterns: [
            FilePattern.include('**/*.dart', description: 'Dart files'),
            FilePattern.exclude('**/*.g.dart', description: 'Generated files'),
          ],
        ),
      ];

      final manager = MultiServiceManager(services, ReloadConfig());

      // Get watched files info (should work even without starting services)
      final watchedFiles = manager.getAllWatchedFiles();

      // Verify the data structure is complete
      expect(watchedFiles, isA<Map<String, dynamic>>());
      expect(watchedFiles['totalWatchers'], isA<int>());
      expect(watchedFiles['totalWatchPaths'], isA<int>());
      expect(watchedFiles['totalPatterns'], isA<int>());
      expect(watchedFiles['services'], isA<List>());
      expect(watchedFiles['uniqueWatchPaths'], isA<List>());
      expect(watchedFiles['summary'], isA<Map>());

      print('✅ Integration test passed - all data structures present');
    });
  });
}
