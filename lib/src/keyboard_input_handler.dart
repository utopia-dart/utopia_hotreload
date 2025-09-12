import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A cross-platform keyboard input handler for hot reload commands.
/// Provides a clean interface for handling single-key commands like 'r' for reload.
class KeyboardInputHandler {
  StreamSubscription? _stdinSubscription;
  final Map<String, void Function()> _commandHandlers = {};
  final void Function()? _onCtrlC;
  final void Function()? _onShutdown;
  bool _isActive = false;

  // Global stdin management to prevent conflicts
  static StreamSubscription? _globalStdinSubscription;
  static final List<KeyboardInputHandler> _activeHandlers = [];

  // Environment detection to avoid Windows VM crashes during testing
  static bool _isTestEnvironment = false;

  // Track if we're in a shutdown scenario to avoid stdin access on Windows
  static bool _isShuttingDown = false;
  static void setTestEnvironment(bool isTest) {
    _isTestEnvironment = isTest;
  }

  /// Marks that the application is shutting down to prevent Windows VM crashes
  static void markShuttingDown() {
    _isShuttingDown = true;
  }

  /// Cleans up global stdin resources - useful for testing
  static Future<void> cleanupGlobalResources() async {
    if (_globalStdinSubscription != null) {
      await _globalStdinSubscription?.cancel();
      _globalStdinSubscription = null;
    }
    _activeHandlers.clear();
    _isShuttingDown = false;
  }

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

    // Add this handler to the active list
    _activeHandlers.add(this);

    _isActive = true;

    if (helpText != null) {
      print(helpText);
    }

    // In test environments, avoid all stdin access to prevent conflicts
    if (_isTestEnvironment) {
      print('📝 Test environment detected - stdin input disabled');
      _setupSignalHandlers();
      return;
    }

    // On non-Windows or during shutdown, avoid stdin access
    if (_isShuttingDown) {
      // Skip all stdin interactions but still set up signal handlers
      _setupSignalHandlers();
      return;
    }

    // Try to enable raw mode if requested and available
    bool useRawMode = false;
    if (rawModeEnabled) {
      try {
        // Use safer Windows stdin access - try raw mode first, fall back if needed
        bool hasTerminal = false;

        if (Platform.isWindows) {
          // On Windows, use extra safety when checking for terminal
          try {
            hasTerminal = stdin.hasTerminal;
          } catch (e) {
            // If we can't safely check terminal status, assume no terminal
            hasTerminal = false;
            print(
                '⚠️  Windows terminal check failed - falling back to line mode');
          }
        } else {
          // On non-Windows platforms, direct access is usually safe
          hasTerminal = stdin.hasTerminal;
        }

        if (hasTerminal) {
          try {
            stdin.echoMode = false;
            stdin.lineMode = false;
            useRawMode = true;

            if (Platform.isWindows) {
              print(
                  '✅ Windows raw mode enabled - background keyboard input active');
            }
          } catch (e) {
            // Failed to set raw mode, fall back to line mode
            useRawMode = false;
            if (Platform.isWindows) {
              print('⚠️  Windows raw mode failed - falling back to line mode');
            }
          }
        } else {
          if (Platform.isWindows) {
            print('ℹ️  No terminal detected on Windows - using line mode');
          }
        }
      } catch (e) {
        // Fall back to line mode if raw mode isn't available
        useRawMode = false;
        print('⚠️  Raw input mode not available, using line mode');
      }
    }

    if (useRawMode) {
      _setupRawModeListener();
    } else {
      _setupGlobalLineModeListener();
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
          print('\n[STOP] Ctrl+C detected - shutting down...');
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

  void _setupGlobalLineModeListener() {
    // Use global stdin listener to prevent conflicts
    // Check if stdin is already being listened to
    if (_globalStdinSubscription == null) {
      try {
        _globalStdinSubscription = stdin
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          final command = line.trim().toLowerCase();
          if (command.isEmpty) return;

          // Create a copy of the list to avoid concurrent modification
          final handlersCopy = List<KeyboardInputHandler>.from(_activeHandlers);

          // Distribute to all active handlers
          for (final handler in handlersCopy) {
            if (!handler._isActive) continue;

            final handlerCommand = handler._commandHandlers[command];
            if (handlerCommand != null) {
              handlerCommand();
            } else {
              // Try single character commands for compatibility
              if (command.length == 1) {
                final charHandler = handler._commandHandlers[command];
                if (charHandler != null) {
                  charHandler();
                }
              }
            }
          }
        }, onError: (_) {}, cancelOnError: false);
      } catch (e) {
        // If stdin is already being listened to, we can't create another listener
        // This is normal in some test scenarios, so we'll just skip stdin setup
        print(
            '⚠️  Stdin already in use - keyboard input disabled for this handler');
      }
    }
  }

  void _setupSignalHandlers() {
    ProcessSignal.sigint.watch().listen((_) async {
      _isShuttingDown = true;
      print('\n[STOP] Ctrl+C detected - shutting down...');
      _onCtrlC?.call();
    });

    try {
      if (!Platform.isWindows) {
        ProcessSignal.sigterm.watch().listen((_) async {
          _isShuttingDown = true;
          print('\n[STOP] SIGTERM received - shutting down...');
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

    // Mark as shutting down to prevent further stdin access on Windows
    _isShuttingDown = true;
    _isActive = false;

    // Remove from active handlers list
    _activeHandlers.remove(this);

    // Cancel individual subscription if it exists
    if (_stdinSubscription != null) {
      await _stdinSubscription?.cancel();
      _stdinSubscription = null;
    }

    // If no more active handlers, clean up global stdin listener
    if (_activeHandlers.isEmpty && _globalStdinSubscription != null) {
      await _globalStdinSubscription?.cancel();
      _globalStdinSubscription = null;
    }

    // On Windows, avoid all stdin access during shutdown to prevent VM crashes
    if (Platform.isWindows) {
      // Windows handles terminal restoration automatically during process exit
      // Attempting to restore terminal settings manually can cause VM crashes
      return;
    }

    // On non-Windows platforms, safely restore terminal settings
    try {
      if (stdin.hasTerminal) {
        try {
          stdin.echoMode = true;
          stdin.lineMode = true;
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
