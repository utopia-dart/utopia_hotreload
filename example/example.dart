#!/usr/bin/env dart

/// Comprehensive example demonstrating Utopia Hot Reload features.
///
/// This example shows how to use the package with a simple HTTP server
/// and demonstrates hot reload/restart functionality.
///
/// To run: `dart run example/example.dart`
import 'dart:io';
import 'package:utopia_hotreload/utopia_hotreload.dart';

void main() async {
  print('🚀 Utopia Hot Reload - Example');
  print('=' * 40);
  print('');

  await DeveloperTools.start(
    script: runApplication,
    watchPaths: ['lib', 'example'],
    watchExtensions: ['.dart'],
    debounceDelay: Duration(milliseconds: 300),
    verbose: false, // Set to true for detailed logging
  );
}

/// Main application logic - this is what gets hot reloaded
Future<void> runApplication() async {
  print('📊 Application starting...');
  print('🕐 Started at: ${DateTime.now()}');
  print('');

  // Create a simple HTTP server
  final server = await HttpServer.bind('localhost', 8080);

  print('🌐 Server running on: http://localhost:8080');
  print('');
  print('Try these endpoints:');
  print('  • http://localhost:8080/ - Home page');
  print('  • http://localhost:8080/api/time - JSON time endpoint');
  print('  • http://localhost:8080/api/status - Server status');
  print('');
  print('💡 Edit this file and save to see hot reload in action!');
  print('');

  // Handle HTTP requests
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
    <title>Utopia hot reload</title>
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
        h1 { color: #ffd700; text-align: center; margin-bottom: 2rem; }
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
        .info-box {
            background: rgba(0, 0, 0, 0.2);
            padding: 1.5rem;
            border-radius: 8px;
            margin: 1.5rem 0;
        }
        code {
            background: rgba(0, 0, 0, 0.3);
            padding: 0.2rem 0.4rem;
            border-radius: 4px;
            font-family: 'Monaco', 'Consolas', monospace;
        }
        ul, ol { margin: 0.5rem 0; }
        li { margin: 0.25rem 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 Hot Reload Demo</h1>
        
        <p>Current time: <span class="highlight">${DateTime.now()}</span></p>
        <p>Server process: <span class="highlight">$pid</span></p>
        
        <div class="info-box">
            <h3>⌨️ Development Commands</h3>
            <p>Use these keyboard shortcuts in your terminal:</p>
            <ul>
                <li><code>r + Enter</code> - Hot reload (preserves state)</li>
                <li><code>R + Enter</code> - Hot restart (full restart)</li>
                <li><code>q + Enter</code> - Quit development server</li>
            </ul>
        </div>
        
        <h3>🔗 API Endpoints</h3>
        <p>Try these endpoints to see the server in action:</p>
        <div>
            <a href="/api/time" class="api-link">📅 Current Time</a>
            <a href="/api/status" class="api-link">📊 Server Status</a>
        </div>
        
        <div class="info-box">
            <h3>🧪 Testing Hot Reload</h3>
            <p>To test hot reload functionality:</p>
            <ol>
                <li>Edit the file <code>example/example.dart</code></li>
                <li>Change this text or modify the styling above</li>
                <li>Save the file</li>
                <li>Refresh this page to see your changes instantly!</li>
            </ol>
            <p><strong>Note:</strong> Hot reload preserves server state, so your connection stays active!</p>
        </div>
    </div>
    
    <script>
        // Auto-refresh every 5 seconds to show live updates
        setTimeout(() => location.reload(), 1000);
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
    'uptime': 'available in full implementation',
    'memory': 'available in full implementation',
    'dart_version': Platform.version.split(' ')[0],
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
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            text-align: center; 
            margin-top: 100px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        h1 { color: #e74c3c; }
        a { color: #ffd700; }
    </style>
</head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The page you're looking for doesn't exist.</p>
    <a href="/">← Go back home</a>
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
