import 'package:test/test.dart';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() {
  group('DeveloperTools', () {
    test('class exists', () {
      expect(DeveloperTools, isNotNull);
    });

    test('start method exists', () {
      expect(DeveloperTools.start, isA<Function>());
    });
  });
}
