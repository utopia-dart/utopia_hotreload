import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A reusable keyboard input handler that supports both raw mode (character-by-character)
/// and line mode input across different platforms.
class KeyboardInputHandler {
  StreamSubscription? _stdinSubscription;
  final Map<String, void Function()> _commandHandlers = {};
  final void Function()? _onCtrlC;
  final void Function()? _onShutdown;
  bool _isActive = false;

  KeyboardInputHandler({
    void Function()? onCtrlC,
    void Function()? onShutdown,
  })  : _onCtrlC = onCtrlC,
        _onShutdown = onShutdown;

  /// Registers a command handler for the given key/command.
  void registerCommand(String command, void Function() handler) {
    _commandHandlers[command.toLowerCase()] = handler;
  }

  /// Starts listening for keyboard input.
  ///
  /// [helpText] - Optional help text to display when starting
  /// [rawModeEnabled] - Whether to attempt raw mode (character input) or use line mode
  Future<void> start({
    String? helpText,
    bool rawModeEnabled = true,
  }) async {
    if (_isActive) return;
    _isActive = true;

    if (helpText != null) {
      print(helpText);
    }

    bool useRawMode = false;

    // Try to enable raw mode if requested and available
    if (rawModeEnabled && stdin.hasTerminal) {
      try {
        stdin.echoMode = false;
        stdin.lineMode = false;
        useRawMode = true;
      } catch (e) {
        // Fall back to line mode if raw mode isn't available (e.g., on Windows)
        useRawMode = false;
        if (Platform.isWindows) {
          // On Windows, don't show warning as this is expected
        } else {
          print('⚠️  Raw input mode not available, using line mode');
        }
      }
    }

    if (useRawMode) {
      _setupRawModeListener();
    } else {
      _setupLineModeListener();
    }

    // Setup signal handlers
    _setupSignalHandlers();
  }

  void _setupRawModeListener() {
    _stdinSubscription = stdin.listen((data) {
      if (!_isActive) return;

      for (final byte in data) {
        // Handle Ctrl+C (byte 3)
        if (byte == 3) {
          print('\n🛑 Ctrl+C detected - shutting down...');
          _onCtrlC?.call();
          return;
        }

        final char = String.fromCharCode(byte).toLowerCase();
        final handler = _commandHandlers[char];
        if (handler != null) {
          print(''); // New line for clean output
          handler();
        }
      }
    }, onError: (_) {}, cancelOnError: false);
  }

  void _setupLineModeListener() {
    _stdinSubscription = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!_isActive) return;

      final command = line.trim().toLowerCase();
      if (command.isEmpty) return;

      final handler = _commandHandlers[command];
      if (handler != null) {
        handler();
      } else {
        // Try single character commands for compatibility
        if (command.length == 1) {
          final charHandler = _commandHandlers[command];
          if (charHandler != null) {
            charHandler();
          }
        }
      }
    }, onError: (_) {}, cancelOnError: false);
  }

  void _setupSignalHandlers() {
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n🛑 Ctrl+C detected - shutting down...');
      _onCtrlC?.call();
    });

    try {
      if (!Platform.isWindows) {
        ProcessSignal.sigterm.watch().listen((_) async {
          print('\n🛑 SIGTERM received - shutting down...');
          _onShutdown?.call();
        });
      }
    } catch (_) {
      // Ignore if the platform doesn't support SIGTERM
    }
  }

  /// Stops listening for keyboard input and restores terminal settings.
  Future<void> stop() async {
    if (!_isActive) return;
    _isActive = false;

    await _stdinSubscription?.cancel();
    _stdinSubscription = null;

    // Restore terminal settings with extra safety
    try {
      if (stdin.hasTerminal) {
        try {
          if (!Platform.isWindows) {
            stdin.echoMode = true;
            stdin.lineMode = true;
          }
        } catch (e) {
          // Ignore terminal restoration errors during shutdown
        }
      }
    } catch (e) {
      // Ignore any errors accessing stdin.hasTerminal during shutdown
    }
  }

  /// Whether the handler is currently active.
  bool get isActive => _isActive;
}
