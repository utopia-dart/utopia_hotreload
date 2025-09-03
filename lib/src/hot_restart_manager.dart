import 'dart:async';
import 'dart:io';

import 'reload_mode.dart';
import 'file_watcher.dart';

/// Hot restart manager that restarts the entire process when files change
/// This is similar to the current HttpDev functionality but more generic
class HotRestartManager {
  final ReloadConfig config;
  final Future<void> Function() script;

  Process? _currentProcess;
  bool _isRestarting = false;
  HotReloadFileWatcher? _fileWatcher;

  HotRestartManager({
    required this.script,
    required this.config,
  });

  /// Start the hot restart development server
  Future<void> start() async {
    // Check if we're already in a child process (to avoid infinite recursion)
    if (Platform.environment['UTOPIA_DEV_CHILD'] == 'true') {
      // We're in the child process, just run the script
      await script();
      return;
    }

    // We're in the parent process, set up hot restart
    print('🚀 Starting Development Server with Hot Restart...');
    print('📁 Watching paths: ${config.watchPaths}');
    print('📄 Watching extensions: ${config.watchExtensions}');
    print('🔄 Hot restart enabled - file changes will restart the process');
    print('');

    // Handle Ctrl+C gracefully
    ProcessSignal.sigint.watch().listen((signal) async {
      print('\\n🛑 Shutting down development server...');
      await _shutdown();
      exit(0);
    });

    // Set up file watcher
    _fileWatcher = HotReloadFileWatcher(config);
    await _fileWatcher!.start((_) => _restartChildProcess());

    print('');

    // Start the initial child process
    await _startChildProcess();

    // Keep the parent process alive
    while (true) {
      await Future.delayed(Duration(seconds: 1));
    }
  }

  /// Start the child process
  Future<void> _startChildProcess() async {
    if (_isRestarting) return;

    try {
      print('🔄 Starting server process...');

      // Get current script path and arguments
      final scriptPath = Platform.script.toFilePath();
      final args = List<String>.from(Platform.executableArguments);

      // Start child process with environment variable to indicate it's a child
      _currentProcess = await Process.start(
        Platform.executable,
        [...args, scriptPath],
        environment: {
          ...Platform.environment,
          'UTOPIA_DEV_CHILD': 'true',
        },
        mode: ProcessStartMode.normal,
      );

      // Forward stdout and stderr
      _currentProcess!.stdout.listen((data) {
        stdout.add(data);
      });

      _currentProcess!.stderr.listen((data) {
        stderr.add(data);
      });

      // Wait for process to exit
      final exitCode = await _currentProcess!.exitCode;

      if (!_isRestarting) {
        if (exitCode == 0) {
          print('✅ Process exited normally');
        } else {
          print('❌ Process exited with code: $exitCode');
        }
      }
    } catch (e) {
      print('❌ Error starting process: $e');
    }
  }

  /// Restart the child process
  Future<void> _restartChildProcess() async {
    if (_isRestarting) return;

    _isRestarting = true;
    print('🔄 Restarting due to file change...');

    if (_currentProcess != null) {
      _currentProcess!.kill(ProcessSignal.sigterm);
      try {
        await _currentProcess!.exitCode.timeout(Duration(seconds: 2));
      } catch (e) {
        // Force kill if graceful shutdown fails
        _currentProcess!.kill(ProcessSignal.sigkill);
      }
    }

    // Small delay to ensure clean shutdown
    await Future.delayed(Duration(milliseconds: 300));

    _isRestarting = false;
    await _startChildProcess();
  }

  /// Shutdown the manager
  Future<void> _shutdown() async {
    if (_currentProcess != null) {
      print('   Stopping child process...');
      _currentProcess!.kill(ProcessSignal.sigint);
      try {
        await _currentProcess!.exitCode.timeout(Duration(seconds: 2));
      } catch (e) {
        // Force kill if graceful shutdown fails
        _currentProcess!.kill(ProcessSignal.sigkill);
      }
    }

    await _fileWatcher?.stop();
    print('✅ Development server stopped');
  }
}
