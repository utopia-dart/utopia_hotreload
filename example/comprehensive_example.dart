#!/usr/bin/env dart

// Comprehensive example demonstrating utopia_hotreload features
//
// This example shows how to use the package with a simple HTTP server
// and demonstrates hot reload/restart functionality.
//
// To run: dart run example/comprehensive_example.dart
import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  print('🚀 Utopia Hot Reload - Comprehensive Example');
  print('=' * 50);
  print('');

  await DeveloperTools.start(
    script: runApplication,
    watchPaths: ['lib', 'example'],
    watchExtensions: ['.dart'],
    debounceDelay: Duration(milliseconds: 300),
    verbose: true,
  );
}

/// Main application logic
Future<void> runApplication() async {
  print('📊 Application starting...');
  print('🕐 Started at: ${DateTime.now()}');
  print('🏠 PID: $pid');
  print('');

  // Create a simple HTTP server with dynamic port allocation
  late HttpServer server;
  int port = 8080;

  try {
    // Try multiple ports starting from 8080
    for (port = 8080; port <= 8090; port++) {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
        break;
      } catch (e) {
        if (port == 8090) rethrow; // If we've tried all ports, give up
        continue; // Try next port
      }
    }
  } catch (e) {
    // If all ports fail, use port 0 for automatic assignment
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;
  }

  print('🌐 Server running on: http://localhost:$port');
  print('');
  print('Try these endpoints:');
  print('  • http://localhost:$port/ - Main page');
  print('  • http://localhost:$port/api/time - JSON time endpoint');
  print('  • http://localhost:$port/api/status - Server status');
  print('');

  // Handle requests
  await for (final request in server) {
    await handleRequest(request);
  }
}

/// Handle HTTP requests
Future<void> handleRequest(HttpRequest request) async {
  final response = request.response;
  final path = request.uri.path;

  try {
    switch (path) {
      case '/':
        await handleHomePage(response);
        break;

      case '/api/time':
        await handleTimeApi(response);
        break;

      case '/api/status':
        await handleStatusApi(response);
        break;

      default:
        await handle404(response);
    }
  } catch (e) {
    await handleError(response, e);
  }
}

/// Home page handler
Future<void> handleHomePage(HttpResponse response) async {
  response.headers.contentType = ContentType.html;

  final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Utopia Hot Reload Demo</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
            line-height: 1.6;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 2rem;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        h1 { color: #ffd700; text-align: center; }
        .highlight { 
            background: rgba(255, 215, 0, 0.2);
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            font-weight: bold;
        }
        .api-link {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            padding: 0.5rem 1rem;
            border-radius: 8px;
            text-decoration: none;
            color: white;
            margin: 0.5rem;
            transition: all 0.3s ease;
        }
        .api-link:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }
        .reload-info {
            background: rgba(0, 0, 0, 0.2);
            padding: 1rem;
            border-radius: 8px;
            margin: 1rem 0;
        }
        code {
            background: rgba(0, 0, 0, 0.3);
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            font-family: 'Monaco', 'Consolas', monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 Utopia Hot Reload Demo</h1>
        
        <p>Current time: <span class="highlight">${DateTime.now()}</span></p>
        <p>Server PID: <span class="highlight">$pid</span></p>
        
        <div class="reload-info">
            <h3>🛠️ Development Commands</h3>
            <p>Use these keyboard shortcuts in your terminal:</p>
            <ul>
                <li><code>r + Enter</code> - Hot reload (preserves state)</li>
                <li><code>R + Enter</code> - Hot restart (full restart)</li>
                <li><code>q + Enter</code> - Quit development server</li>
            </ul>
        </div>
        
        <h3>🔗 API Endpoints</h3>
        <p>Try these API endpoints:</p>
        <div>
            <a href="/api/time" class="api-link">📅 /api/time</a>
            <a href="/api/status" class="api-link">📊 /api/status</a>
        </div>
        
        <div class="reload-info">
            <h3>🧪 Testing Hot Reload</h3>
            <p>To test hot reload functionality:</p>
            <ol>
                <li>Okay this is edited (<code>example/comprehensive_example.dart</code>)</li>
                <li>Change some text or styling</li>
                <li>Save the file</li>
                <li>Refresh this page to see the latest changes!</li>
            </ol>
        </div>
    </div>
    
    <script>
        // Auto-refresh every 5 seconds to show live updates
        setTimeout(() => location.reload(), 5000);
    </script>
</body>
</html>
  ''';

  response.write(html);
  await response.close();
}

/// Time API handler
Future<void> handleTimeApi(HttpResponse response) async {
  response.headers.contentType = ContentType.json;

  final timeData = {
    'timestamp': DateTime.now().toIso8601String(),
    'timezone': DateTime.now().timeZoneName,
    'unix': DateTime.now().millisecondsSinceEpoch,
    'formatted': DateTime.now().toString(),
  };

  response.write(timeData.toString());
  await response.close();
}

/// Status API handler
Future<void> handleStatusApi(HttpResponse response) async {
  response.headers.contentType = ContentType.json;

  final statusData = {
    'status': 'running',
    'pid': pid,
    'uptime': 'unknown', // In a real app, you'd track this
    'memory': 'unknown', // In a real app, you'd check ProcessInfo
    'dart_version': Platform.version,
    'platform': Platform.operatingSystem,
  };

  response.write(statusData.toString());
  await response.close();
}

/// 404 handler
Future<void> handle404(HttpResponse response) async {
  response.statusCode = 404;
  response.headers.contentType = ContentType.html;

  response.write('''
<!DOCTYPE html>
<html>
<head>
    <title>404 - Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; }
        h1 { color: #e74c3c; }
    </style>
</head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The page you're looking for doesn't exist.</p>
    <a href="/">Go back home</a>
</body>
</html>
  ''');

  await response.close();
}

/// Error handler
Future<void> handleError(HttpResponse response, dynamic error) async {
  response.statusCode = 500;
  response.headers.contentType = ContentType.text;
  response.write('Internal Server Error: $error');
  await response.close();

  print('❌ Request error: $error');
}
