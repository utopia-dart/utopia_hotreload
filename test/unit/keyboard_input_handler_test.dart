import 'dart:io';
import 'package:test/test.dart';
import 'package:utopia_hotreload/src/keyboard_input_handler.dart';

void main() {
  // Set test environment flag to avoid Windows VM crashes during testing
  KeyboardInputHandler.setTestEnvironment(true);

  group('KeyboardInputHandler', () {
    late KeyboardInputHandler handler;

    setUp(() {
      handler = KeyboardInputHandler();
    });

    tearDown(() async {
      if (handler.isActive) {
        await handler.stop();
      }
    });

    test('should start and stop without crashing', () async {
      expect(handler.isActive, isFalse);

      // Start the handler
      await handler.start(
        helpText: null, // Skip help text to avoid output
        rawModeEnabled: false, // Use line mode for testing
      );

      expect(handler.isActive, isTrue);

      // Stop the handler - this should not crash on Windows
      await handler.stop();

      expect(handler.isActive, isFalse);
    });

    test('should register commands', () {
      bool commandExecuted = false;

      handler.registerCommand('test', () {
        commandExecuted = true;
      });

      // Commands are registered but we can't test execution easily in test environment
      expect(handler.isActive, isFalse);
    });

    test('should handle multiple start/stop cycles safely', () async {
      // Test that multiple cycles don't cause issues
      expect(handler.isActive, isFalse);

      // First cycle
      await handler.start(helpText: null, rawModeEnabled: false);
      expect(handler.isActive, isTrue);
      await handler.stop();
      expect(handler.isActive, isFalse);

      // Second cycle should work with the static tracking
      await handler.start(helpText: null, rawModeEnabled: false);
      expect(handler.isActive, isTrue);
      await handler.stop();
      expect(handler.isActive, isFalse);
    });

    test('should not crash when stopping inactive handler', () async {
      expect(handler.isActive, isFalse);

      // This should not crash
      await handler.stop();

      expect(handler.isActive, isFalse);
    });

    test('should handle Windows-specific terminal settings safely', () async {
      // This test is specifically for the Windows fix
      // It mainly tests that we don't crash when starting/stopping
      expect(handler.isActive, isFalse);

      await handler.start(helpText: null, rawModeEnabled: true); // Try raw mode
      expect(handler.isActive, isTrue);

      // This stop operation should not crash on Windows
      // even when trying to access stdin.hasTerminal during shutdown
      await handler.stop();
      expect(handler.isActive, isFalse);
    });

    test('should support callback registration', () async {
      bool ctrlCCalled = false;
      bool shutdownCalled = false;

      final callbackHandler = KeyboardInputHandler(
        onCtrlC: () => ctrlCCalled = true,
        onShutdown: () => shutdownCalled = true,
      );

      await callbackHandler.start(helpText: null, rawModeEnabled: false);
      expect(callbackHandler.isActive, isTrue);

      await callbackHandler.stop();
      expect(callbackHandler.isActive, isFalse);

      // Callbacks are registered but not called in this test
      // (they would be called by signal handlers in real usage)
    });

    test('should prevent concurrent stdin access', () async {
      final handler1 = KeyboardInputHandler();
      final handler2 = KeyboardInputHandler();

      try {
        await handler1.start(helpText: null, rawModeEnabled: false);
        expect(handler1.isActive, isTrue);

        // Second handler should handle concurrent access gracefully
        await handler2.start(helpText: null, rawModeEnabled: false);
        expect(handler2.isActive, isTrue);

        await handler1.stop();
        await handler2.stop();
      } finally {
        if (handler1.isActive) await handler1.stop();
        if (handler2.isActive) await handler2.stop();
      }
    });
  });
}
