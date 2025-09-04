import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

void main() {
  group('Real E2E Hot Reload Tests', () {
    late Directory tempDir;
    late File testApp;
    late File pubspecFile;

    setUp(() async {
      // Create a temporary directory for our test app
      tempDir = await Directory.systemTemp.createTemp('hotreload_real_e2e_');

      // Create a minimal pubspec.yaml
      pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  utopia_hotreload:
    path: ${Directory.current.path.replaceAll(r'\', '/')}

dev_dependencies:
  test: ^1.24.0
''');

      // Create the test application
      testApp = File(path.join(tempDir.path, 'test_app.dart'));
      await testApp.writeAsString('''
import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  await DeveloperTools.start(
    script: runApp,
    watchPaths: ['${tempDir.path.replaceAll(r'\', '/')}'],
    watchExtensions: ['.dart'],
    debounceDelay: Duration(milliseconds: 500),
    verbose: false, // Reduce noise in tests
  );
}

Future<void> runApp() async {
  final server = await HttpServer.bind('localhost', 0);
  print('SERVER_PORT:\${server.port}');
  
  await for (final request in server) {
    final response = getResponse();
    request.response
      ..headers.contentType = ContentType.text
      ..write(response)
      ..close();
  }
}

String getResponse() {
  return 'Initial message';
}
''');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should perform real hot reload when source file changes', () async {
      Process? process;

      try {
        // Run pub get first to resolve dependencies
        final pubGetResult = await Process.run(
          'dart',
          ['pub', 'get'],
          workingDirectory: tempDir.path,
        );

        if (pubGetResult.exitCode != 0) {
          fail('Failed to run pub get: ${pubGetResult.stderr}');
        }

        // Start the hot reload application
        process = await Process.start(
          'dart',
          ['test_app.dart'],
          workingDirectory: tempDir.path,
        );

        final serverPortCompleter = Completer<int>();
        final reloadCompleter = Completer<void>();

        // Track output to detect server startup and hot reload events
        process.stdout.transform(utf8.decoder).listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            print('APP: $line');

            // Capture server port
            if (line.startsWith('SERVER_PORT:')) {
              final port = int.parse(line.split(':')[1]);
              if (!serverPortCompleter.isCompleted) {
                serverPortCompleter.complete(port);
              }
            }

            // Detect hot reload completion
            if (line.contains('Hot reload completed') ||
                line.contains('✅ Hot reload completed')) {
              if (!reloadCompleter.isCompleted) {
                reloadCompleter.complete();
              }
            }
          }
        });

        process.stderr.transform(utf8.decoder).listen((data) {
          print('APP ERROR: $data');
        });

        // Wait for server to start
        final serverPort = await serverPortCompleter.future.timeout(
          Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
              'Server failed to start', Duration(seconds: 30)),
        );

        print('Server started on port $serverPort');

        // Test initial response
        final initialResponse =
            await http.get(Uri.parse('http://localhost:$serverPort/'));
        expect(initialResponse.statusCode, equals(200));
        expect(initialResponse.body, contains('Initial message'));
        print('✅ Initial response verified: "${initialResponse.body}"');

        // Wait for system to settle
        await Future.delayed(Duration(milliseconds: 1000));

        // Modify the source file to trigger hot reload
        print('🔄 Modifying source file to trigger hot reload...');
        final updatedContent = await testApp.readAsString();
        final modifiedContent = updatedContent.replaceAll(
          "return 'Initial message';",
          "return 'Hot reloaded message!';",
        );
        await testApp.writeAsString(modifiedContent);

        // Wait for hot reload to complete
        print('⏳ Waiting for hot reload to complete...');
        await reloadCompleter.future.timeout(
          Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
              'Hot reload did not complete', Duration(seconds: 15)),
        );

        print('✅ Hot reload completed');

        // Wait a moment for the change to take effect
        await Future.delayed(Duration(milliseconds: 1000));

        // Test that the server response has been updated via hot reload
        print('🧪 Testing updated response...');
        final updatedResponse =
            await http.get(Uri.parse('http://localhost:$serverPort/'));
        expect(updatedResponse.statusCode, equals(200));
        expect(updatedResponse.body, contains('Hot reloaded message!'));
        print('✅ Hot reload verified: "${updatedResponse.body}"');

        // Send quit command
        process.stdin.writeln('q');

        // Wait for graceful shutdown
        final exitCode = await process.exitCode.timeout(Duration(seconds: 10));
        expect(exitCode, equals(0));
      } catch (e) {
        print('❌ Test failed with error: $e');
        rethrow;
      } finally {
        process?.kill();
      }
    }, timeout: Timeout(Duration(minutes: 3)));
  });
}
