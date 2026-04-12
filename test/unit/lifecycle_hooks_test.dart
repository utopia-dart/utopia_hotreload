import 'package:test/test.dart';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() {
  group('LifecycleHooks', () {
    test('default constructor has all null hooks', () {
      const hooks = LifecycleHooks();
      expect(hooks.onBeforeReload, isNull);
      expect(hooks.onAfterReload, isNull);
      expect(hooks.onBeforeRestart, isNull);
      expect(hooks.onAfterRestart, isNull);
      expect(hooks.onFileChanged, isNull);
      expect(hooks.onError, isNull);
    });

    test('none static constant has all null hooks', () {
      expect(LifecycleHooks.none.onBeforeReload, isNull);
      expect(LifecycleHooks.none.onAfterReload, isNull);
      expect(LifecycleHooks.none.onBeforeRestart, isNull);
      expect(LifecycleHooks.none.onAfterRestart, isNull);
      expect(LifecycleHooks.none.onFileChanged, isNull);
      expect(LifecycleHooks.none.onError, isNull);
    });

    test('individual hooks can be set', () {
      final hooks = LifecycleHooks(
        onBeforeReload: () async => true,
        onAfterReload: () async {},
        onBeforeRestart: () async {},
        onAfterRestart: () async {},
        onFileChanged: (path) async {},
        onError: (error) async {},
      );
      expect(hooks.onBeforeReload, isNotNull);
      expect(hooks.onAfterReload, isNotNull);
      expect(hooks.onBeforeRestart, isNotNull);
      expect(hooks.onAfterRestart, isNotNull);
      expect(hooks.onFileChanged, isNotNull);
      expect(hooks.onError, isNotNull);
    });

    test('onBeforeReload can return false to cancel', () async {
      final hooks = LifecycleHooks(
        onBeforeReload: () async => false,
      );
      final result = await hooks.onBeforeReload!();
      expect(result, isFalse);
    });

    test('onBeforeReload can return true to proceed', () async {
      final hooks = LifecycleHooks(
        onBeforeReload: () async => true,
      );
      final result = await hooks.onBeforeReload!();
      expect(result, isTrue);
    });

    test('onFileChanged receives file path', () async {
      String? receivedPath;
      final hooks = LifecycleHooks(
        onFileChanged: (path) async {
          receivedPath = path;
        },
      );
      await hooks.onFileChanged!('lib/main.dart');
      expect(receivedPath, equals('lib/main.dart'));
    });

    test('onError receives error message', () async {
      String? receivedError;
      final hooks = LifecycleHooks(
        onError: (error) async {
          receivedError = error;
        },
      );
      await hooks.onError!('Something went wrong');
      expect(receivedError, equals('Something went wrong'));
    });

    test('hooks can track call order', () async {
      final callOrder = <String>[];
      final hooks = LifecycleHooks(
        onBeforeReload: () async {
          callOrder.add('beforeReload');
          return true;
        },
        onAfterReload: () async {
          callOrder.add('afterReload');
        },
      );
      await hooks.onBeforeReload!();
      await hooks.onAfterReload!();
      expect(callOrder, equals(['beforeReload', 'afterReload']));
    });

    test('partial hooks - only some set', () {
      final hooks = LifecycleHooks(
        onError: (error) async {},
      );
      expect(hooks.onBeforeReload, isNull);
      expect(hooks.onAfterReload, isNull);
      expect(hooks.onError, isNotNull);
    });
  });
}
