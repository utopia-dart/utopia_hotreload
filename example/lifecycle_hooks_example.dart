import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  print('🔥 Utopia Hot Reload - Lifecycle Hooks Example');
  print('=' * 50);
  print('');

  await DeveloperTools.start(
    script: runServer,
    watchPaths: ['lib', 'example'],
    hooks: LifecycleHooks(
      onFileChanged: (filePath) async {
        print('📁 [Hook] File changed: $filePath');
      },
      onBeforeReload: () async {
        print('🔄 [Hook] Preparing for hot reload...');
        // Return true to proceed, false to cancel
        return true;
      },
      onAfterReload: () async {
        print('✅ [Hook] Hot reload complete!');
      },
      onBeforeRestart: () async {
        print('⏳ [Hook] Closing connections before restart...');
        // Perform cleanup: close DB connections, flush buffers, etc.
      },
      onAfterRestart: () async {
        print('🚀 [Hook] Restart complete, re-initializing...');
      },
      onError: (error) async {
        print('❌ [Hook] Error occurred: $error');
      },
    ),
  );
}

Future<void> runServer() async {
  final server = await HttpServer.bind('localhost', 8081);
  print('🌐 Server running on http://localhost:${server.port}');

  await for (final request in server) {
    request.response
      ..write('Hello from lifecycle hooks example! ${DateTime.now()}')
      ..close();
  }
}
