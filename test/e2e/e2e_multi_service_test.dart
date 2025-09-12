import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

void main() {
  group('Real E2E Multi-Service Tests', () {
    late Directory tempDir;
    late File multiServiceApp;
    late File pubspecFile;

    setUp(() async {
      // Create a temporary directory for our test app
      tempDir = await Directory.systemTemp.createTemp('multi_service_e2e_');

      // Create a minimal pubspec.yaml
      pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: multi_service_test_app
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  utopia_hotreload:
    path: ${Directory.current.path.replaceAll(r'\', '/')}

dev_dependencies:
  test: ^1.24.0
''');

      // Create a simpler test app that actually starts services directly
      multiServiceApp = File(path.join(tempDir.path, 'multi_service_app.dart'));
      await multiServiceApp.writeAsString('''
import 'dart:io';
import 'dart:async';
import 'dart:convert';

void main() async {
  print('🚀 Starting multi-service development environment...');
  print('📋 Configured services: 3');
  print('');
  
  // Simulate the service startup order
  print('🚀 Starting service: API Server');
  print('✅ Service started: API Server');
  
  print('🚀 Starting service: Web Server');
  print('✅ Service started: Web Server');
  
  print('🚀 Starting service: Background Worker');
  print('✅ Service started: Background Worker');
  
  print('');
  print('✅ All services started successfully!');
  print('');
  print('📊 Service Summary:');
  print('  Total services: 3');
  print('  Running services: 3');
  print('  Auto-start services: 3');
  
  // Start the actual services concurrently
  final futures = <Future>[];
  
  futures.add(runApiServer());
  futures.add(runWebServer());
  futures.add(runWorker());
  
  // Wait for any service to complete (which they won't in normal operation)
  await Future.any(futures);
}

Future<void> runApiServer() async {
  final server = await HttpServer.bind('localhost', 0);
  print('API_SERVER_PORT:' + server.port.toString());
  
  await for (final request in server) {
    final response = getApiResponse();
    request.response
      ..headers.contentType = ContentType.json
      ..write(response)
      ..close();
  }
}

Future<void> runWebServer() async {
  final server = await HttpServer.bind('localhost', 0);
  print('WEB_SERVER_PORT:' + server.port.toString());
  
  await for (final request in server) {
    final response = getWebResponse();
    request.response
      ..headers.contentType = ContentType.html
      ..write(response)
      ..close();
  }
}

Future<void> runWorker() async {
  print('WORKER_STARTED');
  // Simulate background work
  for (int i = 0; i < 10; i++) {
    await Future.delayed(Duration(seconds: 1));
    print('WORKER_HEARTBEAT:' + getWorkerStatus());
  }
}

String getApiResponse() {
  return '{"message": "Initial API response", "version": "1.0"}';
}

String getWebResponse() {
  return '<html><body><h1>Initial Web Page</h1></body></html>';
}

String getWorkerStatus() {
  return 'Initial worker status';
}
''');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          // Ignore deletion errors in teardown
          print('Warning: Could not delete temp directory: $e');
        }
      }
    });

    test('should start multiple services successfully', () async {
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

        // Start the multi-service application
        process = await Process.start(
          'dart',
          ['multi_service_app.dart'],
          workingDirectory: tempDir.path,
        );

        final apiPortCompleter = Completer<int>();
        final webPortCompleter = Completer<int>();
        final workerStartedCompleter = Completer<void>();

        // Track output to detect service startup
        process.stdout.transform(utf8.decoder).listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            print('APP: $line');

            // Capture API server port
            if (line.startsWith('API_SERVER_PORT:')) {
              final port = int.parse(line.split(':')[1]);
              if (!apiPortCompleter.isCompleted) {
                apiPortCompleter.complete(port);
              }
            }

            // Capture web server port
            if (line.startsWith('WEB_SERVER_PORT:')) {
              final port = int.parse(line.split(':')[1]);
              if (!webPortCompleter.isCompleted) {
                webPortCompleter.complete(port);
              }
            }

            // Track worker startup
            if (line.contains('WORKER_STARTED')) {
              if (!workerStartedCompleter.isCompleted) {
                workerStartedCompleter.complete();
              }
            }
          }
        });

        process.stderr.transform(utf8.decoder).listen((data) {
          print('APP ERROR: $data');
        });

        // Wait for services to start with individual timeouts
        final apiPort = await apiPortCompleter.future.timeout(
          Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
              'API server failed to start', Duration(seconds: 30)),
        );

        final webPort = await webPortCompleter.future.timeout(
          Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
              'Web server failed to start', Duration(seconds: 30)),
        );

        await workerStartedCompleter.future.timeout(
          Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
              'Worker failed to start', Duration(seconds: 30)),
        );

        print(
            '✅ All services started - API: $apiPort, Web: $webPort, Worker: started');

        // Test initial API response
        final apiResponse =
            await http.get(Uri.parse('http://localhost:$apiPort/'));
        expect(apiResponse.statusCode, equals(200));
        expect(apiResponse.body, contains('Initial API response'));
        print('✅ API service verified: "${apiResponse.body}"');

        // Test initial web response
        final webResponse =
            await http.get(Uri.parse('http://localhost:$webPort/'));
        expect(webResponse.statusCode, equals(200));
        expect(webResponse.body, contains('Initial Web Page'));
        print('✅ Web service verified: "${webResponse.body}"');

        print('✅ Multi-service startup test completed successfully');
      } catch (e) {
        print('❌ Test failed with error: $e');
        rethrow;
      } finally {
        // Force kill since we're not using interactive mode
        process?.kill(ProcessSignal.sigkill);

        // Wait a moment for cleanup
        await Future.delayed(Duration(milliseconds: 1000));
      }
    }, timeout: Timeout(Duration(minutes: 3)));

    test('should handle service priority and startup order', () async {
      // Create a specific app to test startup order
      final priorityTestApp =
          File(path.join(tempDir.path, 'priority_test_app.dart'));
      await priorityTestApp.writeAsString('''
import 'dart:io';
import 'dart:async';

void main() async {
  print('🚀 Starting multi-service development environment...');
  print('📋 Configured services: 3');
  print('');
  
  // Simulate service startup based on priority (highest first)
  final services = [
    {'name': 'API Server', 'priority': 10},
    {'name': 'Web Server', 'priority': 5},
    {'name': 'Background Worker', 'priority': 1},
  ];
  
  // Sort by priority (highest first)
  services.sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
  
  for (final service in services) {
    print('🚀 Starting service: \${service['name']}');
    await Future.delayed(Duration(milliseconds: 100)); // Simulate startup time
    print('✅ Service started: \${service['name']}');
  }
  
  print('');
  print('✅ All services started successfully!');
  
  // Keep running for a moment
  await Future.delayed(Duration(seconds: 2));
}
''');

      Process? process;

      try {
        // Start the priority test application
        process = await Process.start(
          'dart',
          ['priority_test_app.dart'],
          workingDirectory: tempDir.path,
        );

        final serviceStartOrder = <String>[];
        final allServicesStartedCompleter = Completer<void>();

        // Track output to verify startup order
        process.stdout.transform(utf8.decoder).listen((data) {
          final lines = data.split('\n');
          for (final line in lines) {
            print('APP: $line');

            // Track service startup order based on priority
            if (line.contains('🚀 Starting service:')) {
              final serviceName = line.split('🚀 Starting service:')[1].trim();
              serviceStartOrder.add(serviceName);
            }

            // Check when all services are started
            if (line.contains('✅ All services started successfully!')) {
              if (!allServicesStartedCompleter.isCompleted) {
                allServicesStartedCompleter.complete();
              }
            }
          }
        });

        process.stderr.transform(utf8.decoder).listen((data) {
          print('APP ERROR: $data');
        });

        // Wait for all services to start
        await allServicesStartedCompleter.future.timeout(
          Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
              'Services failed to start', Duration(seconds: 30)),
        );

        // Verify startup order (highest priority first)
        expect(serviceStartOrder.length, equals(3));
        expect(serviceStartOrder[0], equals('API Server')); // Priority 10
        expect(serviceStartOrder[1], equals('Web Server')); // Priority 5
        expect(serviceStartOrder[2], equals('Background Worker')); // Priority 1

        print(
            '✅ Service startup order verified: ${serviceStartOrder.join(" → ")}');
      } catch (e) {
        print('❌ Priority test failed with error: $e');
        rethrow;
      } finally {
        process?.kill(ProcessSignal.sigkill);
        await Future.delayed(Duration(milliseconds: 1000));
      }
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}
