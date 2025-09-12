import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:utopia_hotreload/utopia_hotreload.dart';

/// Multi-Service Development Example
///
/// This demonstrates running multiple services simultaneously with hot reload.
/// Each service has its own configuration and can be managed independently.
void main() async {
  print('🚀 Multi-Service Development Environment');
  print('=' * 50);
  print('');

  await DeveloperTools.startMultiple(
    [
      // API Server - handles REST endpoints
      ServiceConfig(
        name: 'api-server',
        script: runApiServer,
        displayName: 'API Server',
        watchPaths: ['example', 'lib'],
        priority: 10, // Higher priority - starts first
        autoStart: true,
      ),

      // Web Server - serves static content and frontend
      ServiceConfig(
        name: 'web-server',
        script: runWebServer,
        displayName: 'Web Server',
        watchPaths: ['example'],
        watchExtensions: ['.dart', '.html', '.css'],
        priority: 5, // Lower priority - starts second
        autoStart: true,
      ),

      // Background Worker - processes tasks
      ServiceConfig(
        name: 'worker',
        script: runBackgroundWorker,
        displayName: 'Background Worker',
        watchPaths: ['example'],
        priority: 1, // Lowest priority - starts last
        autoStart: true,
        verbose: true, // Enable detailed logging for this service
      ),
    ],
    globalWatchPaths: ['example'], // Default for all services
    verbose: false, // Global verbose setting
  );
}

/// API Server - REST endpoints on port 3000
Future<void> runApiServer() async {
  final server = await HttpServer.bind('localhost', 3000);
  print('🌐 API Server running on: http://localhost:3000');

  await for (final request in server) {
    await handleApiRequest(request);
  }
}

Future<void> handleApiRequest(HttpRequest request) async {
  final response = request.response;
  response.headers.add('Access-Control-Allow-Origin', '*');
  response.headers.contentType = ContentType.json;

  switch (request.uri.path) {
    case '/api/status':
      response.write(jsonEncode({
        'status': 'running',
        'service': 'api-server',
        'time': DateTime.now().toIso8601String(),
        'message': 'API Server is healthy! 🟢',
      }));
      break;

    case '/api/users':
      response.write(jsonEncode({
        'users': [
          {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'},
          {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'},
        ],
        'count': 2,
        'message': 'Users fetched successfully! 👥',
      }));
      break;

    case '/api/data':
      // Try editing this data and save to see hot reload!
      response.write(jsonEncode({
        'data': {
          'temperature': 23.5,
          'humidity': 65.2,
          'status': 'optimal',
          'updated': DateTime.now().toIso8601String(),
        },
        'source': 'multi-service-demo',
        'message': 'Sensor data retrieved! 📊',
      }));
      break;

    default:
      response.statusCode = 404;
      response.write(jsonEncode({
        'error': 'Not Found',
        'path': request.uri.path,
        'message': 'API endpoint not found',
      }));
  }

  await response.close();
}

/// Web Server - serves frontend on port 8080
Future<void> runWebServer() async {
  final server = await HttpServer.bind('localhost', 8080);
  print('🌐 Web Server running on: http://localhost:8080');

  await for (final request in server) {
    await handleWebRequest(request);
  }
}

Future<void> handleWebRequest(HttpRequest request) async {
  final response = request.response;

  switch (request.uri.path) {
    case '/':
      await serveHomePage(response);
      break;

    case '/status':
      await serveStatusPage(response);
      break;

    case '/dashboard':
      await serveDashboardPage(response);
      break;

    default:
      response.statusCode = 404;
      response.headers.contentType = ContentType.html;
      response.write('''
        <!DOCTYPE html>
        <html>
        <head><title>404 - Not Found</title></head>
        <body>
          <h1>Page Not Found</h1>
          <p>The requested page was not found.</p>
          <a href="/">Go Home</a>
        </body>
        </html>
      ''');
  }

  await response.close();
}

Future<void> serveHomePage(HttpResponse response) async {
  response.headers.contentType = ContentType.html;
  response.write('''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Multi-Service Demo</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .service { background: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 10px; }
        .status { color: #4CAF50; font-weight: bold; }
        button { background: #2196F3; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        button:hover { background: #1976D2; }
      </style>
    </head>
    <body>
      <h1>🚀 Multi-Service Development Demo</h1>
      <p>This page is served by the <strong>Web Server</strong> service.</p>
      
      <div class="service">
        <h3>🌐 Web Server (Port 8080)</h3>
        <p class="status">✅ Running</p>
        <p>Serves this frontend interface and static content.</p>
        <button onclick="location.reload()">Refresh Page</button>
      </div>
      
      <div class="service">
        <h3>🔌 API Server (Port 3000)</h3>
        <p class="status">✅ Running</p>
        <p>Provides REST API endpoints for data.</p>
        <button onclick="testApi()">Test API</button>
        <div id="api-result"></div>
      </div>
      
      <div class="service">
        <h3>⚙️ Background Worker</h3>
        <p class="status">✅ Running</p>
        <p>Processes background tasks and jobs.</p>
      </div>
      
      <h2>🔥 Hot Reload Features</h2>
      <ul>
        <li>Edit any service code and save to see hot reload in action</li>
        <li>Each service reloads independently</li>
        <li>Try changing the API responses or this page content</li>
        <li>Use terminal commands: r (reload), l (list), q (quit)</li>
      </ul>
      
      <p><a href="/status">📊 Service Status</a> | <a href="/dashboard">📈 Dashboard</a></p>
      
      <script>
        async function testApi() {
          try {
            const response = await fetch('http://localhost:3000/api/status');
            const data = await response.json();
            document.getElementById('api-result').innerHTML = 
              '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
          } catch (e) {
            document.getElementById('api-result').innerHTML = 
              '<p style="color: red;">Error: ' + e.message + '</p>';
          }
        }
      </script>
    </body>
    </html>
  ''');
}

Future<void> serveStatusPage(HttpResponse response) async {
  response.headers.contentType = ContentType.html;
  response.write('''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Service Status</title>
      <meta http-equiv="refresh" content="5">
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .metric { background: #e3f2fd; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .healthy { color: #4CAF50; }
      </style>
    </head>
    <body>
      <h1>📊 Service Status Dashboard</h1>
      <p><em>Auto-refreshes every 5 seconds</em></p>
      
      <div class="metric">
        <h3 class="healthy">🟢 All Services Running</h3>
        <p>Last updated: ${DateTime.now()}</p>
      </div>
      
      <div class="metric">
        <h4>🌐 Web Server</h4>
        <p>Status: <span class="healthy">Healthy</span></p>
        <p>Port: 8080</p>
      </div>
      
      <div class="metric">
        <h4>🔌 API Server</h4>
        <p>Status: <span class="healthy">Healthy</span></p>
        <p>Port: 3000</p>
      </div>
      
      <div class="metric">
        <h4>⚙️ Background Worker</h4>
        <p>Status: <span class="healthy">Active</span></p>
        <p>Mode: Processing</p>
      </div>
      
      <p><a href="/">← Back to Home</a></p>
    </body>
    </html>
  ''');
}

Future<void> serveDashboardPage(HttpResponse response) async {
  response.headers.contentType = ContentType.html;
  response.write('''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Development Dashboard</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .card { background: #f9f9f9; padding: 20px; border-radius: 10px; }
        .highlight { background: #fff3cd; padding: 10px; border-radius: 5px; margin: 10px 0; }
      </style>
    </head>
    <body>
      <h1>📈 Development Dashboard</h1>
      
      <div class="highlight">
        <strong>💡 Try this:</strong> Edit any of the service scripts and save to see hot reload in action!
      </div>
      
      <div class="grid">
        <div class="card">
          <h3>🔥 Hot Reload Status</h3>
          <p>✅ File watching active</p>
          <p>✅ Multi-service mode enabled</p>
          <p>✅ Independent reload per service</p>
        </div>
        
        <div class="card">
          <h3>📂 Watched Paths</h3>
          <ul>
            <li>example/ (all services)</li>
            <li>lib/ (api-server only)</li>
          </ul>
        </div>
        
        <div class="card">
          <h3>⚡ Quick Actions</h3>
          <p>Terminal commands:</p>
          <ul>
            <li><code>r</code> - Reload all services</li>
            <li><code>l</code> - List service status</li>
            <li><code>s</code> - Stop a service</li>
            <li><code>t</code> - Start a service</li>
            <li><code>q</code> - Quit all</li>
          </ul>
        </div>
        
        <div class="card">
          <h3>🔗 Service Endpoints</h3>
          <ul>
            <li><a href="http://localhost:8080/">Web Server</a></li>
            <li><a href="http://localhost:3000/api/status">API Status</a></li>
            <li><a href="http://localhost:3000/api/users">API Users</a></li>
            <li><a href="http://localhost:3000/api/data">API Data</a></li>
          </ul>
        </div>
      </div>
      
      <p><a href="/">← Back to Home</a></p>
    </body>
    </html>
  ''');
}

/// Background Worker - processes jobs and tasks
Future<void> runBackgroundWorker() async {
  print('⚙️  Background Worker starting...');
  print('📋 Worker tasks:');
  print('  • Data processing');
  print('  • Cache management');
  print('  • Health monitoring');
  print('');

  int taskCount = 0;

  // Simulate background processing
  Timer.periodic(Duration(seconds: 10), (timer) {
    taskCount++;
    print('⚙️  [Worker] Processing task #$taskCount - ${DateTime.now()}');

    // Try changing this message and save to see hot reload!
    final tasks = [
      'Cleaning cache entries',
      'Processing user uploads',
      'Generating reports',
      'Monitoring system health',
      'Backing up data',
      'Optimizing database',
    ];

    final task = tasks[taskCount % tasks.length];
    print('⚙️  [Worker] Task: $task');
  });

  // Keep the worker running
  while (true) {
    await Future.delayed(Duration(seconds: 1));
  }
}
