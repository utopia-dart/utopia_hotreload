import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../multi_service_manager.dart';
import '../file_watcher.dart';
import 'metrics_collector.dart';
import 'reload_history.dart';
import 'package:path/path.dart' as path;

/// Real-time dashboard service for monitoring hot reload and multi-service development.
///
/// Provides a web-based dashboard with live updates on service status, performance metrics,
/// hot reload activity, and interactive service management capabilities.
class DashboardService {
  static const int defaultPort = 9000;
  static const String defaultHost = 'localhost';

  final String host;
  final int port;
  final bool enabled;
  final Duration updateInterval;

  late HttpServer _server;
  late Timer _updateTimer;
  late MetricsCollector _metricsCollector;
  late ReloadHistory _reloadHistory;

  MultiServiceManager? _serviceManager;
  HotReloadFileWatcher? _fileWatcher;
  bool _isRunning = false;

  final List<WebSocket> _connectedClients = [];
  final Map<String, dynamic> _cachedDashboardData = {};

  DashboardService({
    this.host = defaultHost,
    this.port = defaultPort,
    this.enabled = true,
    this.updateInterval = const Duration(seconds: 2),
  });

  /// Starts the dashboard HTTP server and WebSocket endpoint.
  Future<void> start() async {
    if (!enabled || _isRunning) return;

    try {
      _server = await HttpServer.bind(host, port);
      _metricsCollector = MetricsCollector();
      _reloadHistory = ReloadHistory();

      print('📊 Dashboard server starting on http://$host:$port');

      _server.listen(_handleRequest);
      _startUpdateTimer();

      _isRunning = true;
      print('✅ Dashboard service running on http://$host:$port');
    } catch (e) {
      print('❌ Failed to start dashboard service: $e');
      rethrow;
    }
  }

  /// Stops the dashboard service and cleans up resources.
  Future<void> stop() async {
    if (!_isRunning) return;

    _updateTimer.cancel();

    // Close all WebSocket connections
    for (final client in _connectedClients) {
      await client.close();
    }
    _connectedClients.clear();

    await _server.close();

    _isRunning = false;
    print('✅ Dashboard service stopped');
  }

  /// Registers a multi-service manager for monitoring.
  void attachServiceManager(MultiServiceManager manager) {
    _serviceManager = manager;
    _metricsCollector.attachServiceManager(manager);
  }

  /// Attaches a file watcher for monitoring watched files.
  void attachFileWatcher(HotReloadFileWatcher fileWatcher) {
    _fileWatcher = fileWatcher;
  }

  /// Records a hot reload event for tracking and analytics.
  void recordReloadEvent({
    required String serviceName,
    required String type, // 'hot_reload', 'hot_restart', 'failed'
    required Duration duration,
    String? error,
    List<String>? changedFiles,
  }) {
    _reloadHistory.addEvent(
      serviceName: serviceName,
      type: type,
      duration: duration,
      error: error,
      changedFiles: changedFiles,
    );

    // Immediately broadcast the update to connected clients
    _broadcastUpdate();
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    try {
      switch (path) {
        case '/':
          await _serveDashboard(request.response);
          break;
        case '/ws':
          await _handleWebSocket(request);
          break;
        case '/api/status':
          await _serveApiStatus(request.response);
          break;
        case '/api/metrics':
          await _serveApiMetrics(request.response);
          break;
        case '/api/reload-history':
          await _serveApiReloadHistory(request.response);
          break;
        case '/api/services':
          await _serveApiServices(request.response);
          break;
        case '/api/watched-files':
          await _serveApiWatchedFiles(request.response);
          break;
        case '/api/services/restart':
          await _handleServiceRestart(request);
          break;
        case '/api/services/stop':
          await _handleServiceStop(request);
          break;
        case '/api/services/start':
          await _handleServiceStart(request);
          break;
        default:
          await _serve404(request.response);
      }
    } catch (e) {
      print('❌ Dashboard request error: $e');
      await _serveError(request.response, e);
    }
  }

  Future<void> _handleWebSocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _connectedClients.add(socket);

    print('📡 Dashboard client connected (${_connectedClients.length} total)');

    // Send initial data
    socket.add(jsonEncode({
      'type': 'initial_data',
      'data': await _collectDashboardData(),
    }));

    socket.listen(
      (data) => _handleWebSocketMessage(socket, data),
      onDone: () {
        _connectedClients.remove(socket);
        print(
            '📡 Dashboard client disconnected (${_connectedClients.length} total)');
      },
      onError: (error) {
        print('❌ Dashboard WebSocket error: $error');
        _connectedClients.remove(socket);
      },
    );
  }

  void _handleWebSocketMessage(WebSocket socket, dynamic data) {
    try {
      final message = jsonDecode(data);
      final type = message['type'];

      switch (type) {
        case 'ping':
          socket.add(jsonEncode({'type': 'pong'}));
          break;
        case 'request_update':
          socket.add(jsonEncode({
            'type': 'update',
            'data': _cachedDashboardData,
          }));
          break;
      }
    } catch (e) {
      print('❌ Invalid WebSocket message: $e');
    }
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(updateInterval, (_) async {
      await _updateDashboardData();
      _broadcastUpdate();
    });
  }

  Future<void> _updateDashboardData() async {
    _cachedDashboardData.clear();
    _cachedDashboardData.addAll(await _collectDashboardData());
  }

  void _broadcastUpdate() {
    if (_connectedClients.isEmpty) return;

    final message = jsonEncode({
      'type': 'update',
      'data': _cachedDashboardData,
    });

    // Remove disconnected clients while broadcasting
    _connectedClients.removeWhere((client) {
      try {
        client.add(message);
        return false;
      } catch (e) {
        return true; // Remove this client
      }
    });
  }

  Future<Map<String, dynamic>> _collectDashboardData() async {
    final data = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'services': _serviceManager?.getServiceStatuses() ?? [],
      'metrics': await _metricsCollector.collectMetrics(),
      'reloadHistory': _reloadHistory.getRecentEvents(limit: 50),
      'systemInfo': await _collectSystemInfo(),
      'watchedFiles': _fileWatcher?.getWatchInfo(),
    };

    return data;
  }

  Future<Map<String, dynamic>> _collectSystemInfo() async {
    final info = <String, dynamic>{
      'dartVersion': Platform.version,
      'platform': Platform.operatingSystem,
      'architecture': Platform.localeName,
      'uptime': _metricsCollector.getUptime(),
      'pid': pid,
    };

    return info;
  }

  Future<void> _serveDashboard(HttpResponse response) async {
    response.headers.contentType = ContentType.html;

    final html = await _generateDashboardHtml();
    response.write(html);
    await response.close();
  }

  Future<void> _serveApiStatus(HttpResponse response) async {
    response.headers.contentType = ContentType.json;
    response.headers.add('Access-Control-Allow-Origin', '*');

    final status = {
      'status': 'running',
      'uptime': _metricsCollector.getUptime(),
      'services': _serviceManager?.getServiceStatuses().length ?? 0,
      'connectedClients': _connectedClients.length,
    };

    response.write(jsonEncode(status));
    await response.close();
  }

  Future<void> _serveApiMetrics(HttpResponse response) async {
    response.headers.contentType = ContentType.json;
    response.headers.add('Access-Control-Allow-Origin', '*');

    final metrics = await _metricsCollector.collectMetrics();
    response.write(jsonEncode(metrics));
    await response.close();
  }

  Future<void> _serveApiReloadHistory(HttpResponse response) async {
    response.headers.contentType = ContentType.json;
    response.headers.add('Access-Control-Allow-Origin', '*');

    final history = _reloadHistory.getRecentEvents(limit: 100);
    response.write(jsonEncode(history));
    await response.close();
  }

  Future<void> _serveApiServices(HttpResponse response) async {
    response.headers.contentType = ContentType.json;
    response.headers.add('Access-Control-Allow-Origin', '*');

    final services = _serviceManager?.getServiceStatuses() ?? [];
    response.write(jsonEncode(services));
    await response.close();
  }

  Future<void> _serveApiWatchedFiles(HttpResponse response) async {
    response.headers.contentType = ContentType.json;
    response.headers.add('Access-Control-Allow-Origin', '*');

    final watchInfo = _fileWatcher?.getWatchInfo() ??
        {
          'watchPaths': [],
          'watchExtensions': [],
          'ignorePatterns': [],
          'isActive': false,
          'matcherInfo': {},
          'debounceMs': 0,
          'verbose': false,
        };

    response.write(jsonEncode(watchInfo));
    await response.close();
  }

  Future<void> _handleServiceRestart(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body);
    final serviceName = data['serviceName'] as String?;

    if (serviceName != null && _serviceManager != null) {
      await _serviceManager!.restartService(serviceName);
    }

    await _sendJsonResponse(request.response, {'success': true});
  }

  Future<void> _handleServiceStop(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body);
    final serviceName = data['serviceName'] as String?;

    if (serviceName != null && _serviceManager != null) {
      await _serviceManager!.stopService(serviceName);
    }

    await _sendJsonResponse(request.response, {'success': true});
  }

  Future<void> _handleServiceStart(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body);
    final serviceName = data['serviceName'] as String?;

    if (serviceName != null && _serviceManager != null) {
      await _serviceManager!.startService(serviceName);
    }

    await _sendJsonResponse(request.response, {'success': true});
  }

  Future<void> _sendJsonResponse(
      HttpResponse response, Map<String, dynamic> data) async {
    response.headers.contentType = ContentType.json;
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _serve404(HttpResponse response) async {
    response.statusCode = 404;
    response.headers.contentType = ContentType.html;
    response.write('<h1>404 - Not Found</h1>');
    await response.close();
  }

  Future<void> _serveError(HttpResponse response, dynamic error) async {
    response.statusCode = 500;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'error': error.toString()}));
    await response.close();
  }

  Future<String> _generateDashboardHtml() async {
    try {
      // Try multiple possible locations for the HTML template
      final possiblePaths = [
        // Direct path when running from package
        path.join('lib', 'src', 'dashboard', 'dashboard.html'),
        // Path when running from example directory
        path.join('..', 'lib', 'src', 'dashboard', 'dashboard.html'),
        // Absolute path approach
        path.join(Directory.current.path, 'lib', 'src', 'dashboard',
            'dashboard.html'),
      ];

      for (final htmlPath in possiblePaths) {
        final htmlFile = File(htmlPath);
        if (await htmlFile.exists()) {
          return await htmlFile.readAsString();
        }
      }

      // Fallback to embedded HTML if file not found
      print('⚠️  Dashboard HTML file not found, using fallback');
      return _getFallbackHtml();
    } catch (e) {
      print('⚠️  Error loading dashboard HTML: $e, using fallback');
      return _getFallbackHtml();
    }
  }

  String _getFallbackHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🔥 Utopia Hot Reload Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0f172a;
            color: #e2e8f0;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px 0;
            border-bottom: 2px solid #1e293b;
        }
        
        h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            background: linear-gradient(135deg, #f59e0b, #ef4444);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .subtitle {
            color: #94a3b8;
            font-size: 1.1rem;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .card {
            background: #1e293b;
            border-radius: 12px;
            padding: 20px;
            border: 1px solid #334155;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        
        .card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
        }
        
        .card-header {
            display: flex;
            align-items: center;
            margin-bottom: 15px;
            font-weight: 600;
            font-size: 1.1rem;
        }
        
        .card-header .emoji {
            margin-right: 10px;
            font-size: 1.3rem;
        }
        
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-running { background: #10b981; }
        .status-stopped { background: #64748b; }
        .status-error { background: #ef4444; }
        
        .metric {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #334155;
        }
        
        .metric:last-child {
            border-bottom: none;
        }
        
        .metric-value {
            font-weight: 600;
            color: #f59e0b;
        }
        
        .service-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px;
            margin: 8px 0;
            background: #0f172a;
            border-radius: 8px;
            border: 1px solid #334155;
        }
        
        .service-name {
            font-weight: 600;
        }
        
        .service-actions {
            display: flex;
            gap: 8px;
        }
        
        .btn {
            padding: 6px 12px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.85rem;
            font-weight: 500;
            transition: background-color 0.2s ease;
        }
        
        .btn-primary { background: #3b82f6; color: white; }
        .btn-primary:hover { background: #2563eb; }
        
        .btn-danger { background: #ef4444; color: white; }
        .btn-danger:hover { background: #dc2626; }
        
        .btn-success { background: #10b981; color: white; }
        .btn-success:hover { background: #059669; }
        
        .reload-event {
            padding: 10px;
            margin: 5px 0;
            background: #0f172a;
            border-radius: 6px;
            border-left: 4px solid #3b82f6;
            font-size: 0.9rem;
        }
        
        .reload-event.failed {
            border-left-color: #ef4444;
        }
        
        .reload-event.restart {
            border-left-color: #f59e0b;
        }
        
        .reload-time {
            color: #64748b;
            font-size: 0.8rem;
        }
        
        .connection-status {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 10px 15px;
            border-radius: 6px;
            font-weight: 600;
            z-index: 1000;
        }
        
        .connected {
            background: #10b981;
            color: white;
        }
        
        .disconnected {
            background: #ef4444;
            color: white;
        }
        
        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
            }
            
            .container {
                padding: 10px;
            }
            
            h1 {
                font-size: 2rem;
            }
        }
    </style>
</head>
<body>
    <div class="connection-status" id="connectionStatus">
        🔌 Connecting...
    </div>
    
    <div class="container">
        <header>
            <h1>🔥 Utopia Hot Reload Dashboard</h1>
            <p class="subtitle">Real-time monitoring and management for your development environment</p>
        </header>
        
        <div class="grid">
            <!-- System Overview -->
            <div class="card">
                <div class="card-header">
                    <span class="emoji">📊</span>
                    System Overview
                </div>
                <div id="systemOverview">
                    <div class="metric">
                        <span>Uptime</span>
                        <span class="metric-value" id="uptime">--</span>
                    </div>
                    <div class="metric">
                        <span>Active Services</span>
                        <span class="metric-value" id="activeServices">--</span>
                    </div>
                    <div class="metric">
                        <span>Total Reloads</span>
                        <span class="metric-value" id="totalReloads">--</span>
                    </div>
                    <div class="metric">
                        <span>Connected Clients</span>
                        <span class="metric-value" id="connectedClients">--</span>
                    </div>
                </div>
            </div>
            
            <!-- Services -->
            <div class="card">
                <div class="card-header">
                    <span class="emoji">⚙️</span>
                    Services
                </div>
                <div id="servicesList">
                    <!-- Services will be populated by JavaScript -->
                </div>
            </div>
            
            <!-- Performance Metrics -->
            <div class="card">
                <div class="card-header">
                    <span class="emoji">📈</span>
                    Performance
                </div>
                <div id="performanceMetrics">
                    <div class="metric">
                        <span>Average Reload Time</span>
                        <span class="metric-value" id="avgReloadTime">--</span>
                    </div>
                    <div class="metric">
                        <span>Memory Usage</span>
                        <span class="metric-value" id="memoryUsage">--</span>
                    </div>
                    <div class="metric">
                        <span>File Watches</span>
                        <span class="metric-value" id="fileWatches">--</span>
                    </div>
                </div>
            </div>
            
            <!-- Watched Files -->
            <div class="card">
                <div class="card-header">
                    <span class="emoji">👁️</span>
                    Watched Files
                </div>
                <div id="watchedFilesMetrics">
                    <div class="metric">
                        <span>Total Watchers</span>
                        <span class="metric-value" id="totalWatchers">--</span>
                    </div>
                    <div class="metric">
                        <span>Watch Paths</span>
                        <span class="metric-value" id="totalWatchPaths">--</span>
                    </div>
                    <div class="metric">
                        <span>Filter Patterns</span>
                        <span class="metric-value" id="totalPatterns">--</span>
                    </div>
                    <div style="margin-top: 10px;">
                        <button onclick="dashboard.toggleWatchedFilesDetails()" id="watchDetailsToggle">
                            Show Details
                        </button>
                    </div>
                    <div id="watchedFilesDetails" style="display: none; margin-top: 10px; font-size: 12px;">
                        <!-- Detailed watched files info will be populated by JavaScript -->
                    </div>
                </div>
            </div>
            
            <!-- Recent Reload Activity -->
            <div class="card">
                <div class="card-header">
                    <span class="emoji">🔄</span>
                    Recent Activity
                </div>
                <div id="reloadHistory" style="max-height: 300px; overflow-y: auto;">
                    <!-- Reload events will be populated by JavaScript -->
                </div>
            </div>
        </div>
    </div>

    <script>
        class DashboardClient {
            constructor() {
                this.ws = null;
                this.reconnectAttempts = 0;
                this.maxReconnectAttempts = 5;
                this.reconnectDelay = 1000;
                this.isConnected = false;
                
                this.connect();
            }
            
            connect() {
                const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = protocol + '//' + window.location.host + '/ws';
                
                try {
                    this.ws = new WebSocket(wsUrl);
                    
                    this.ws.onopen = () => {
                        console.log('Connected to dashboard');
                        this.isConnected = true;
                        this.reconnectAttempts = 0;
                        this.updateConnectionStatus(true);
                    };
                    
                    this.ws.onmessage = (event) => {
                        try {
                            const message = JSON.parse(event.data);
                            this.handleMessage(message);
                        } catch (e) {
                            console.error('Failed to parse message:', e);
                        }
                    };
                    
                    this.ws.onclose = () => {
                        console.log('Disconnected from dashboard');
                        this.isConnected = false;
                        this.updateConnectionStatus(false);
                        this.scheduleReconnect();
                    };
                    
                    this.ws.onerror = (error) => {
                        console.error('WebSocket error:', error);
                    };
                } catch (e) {
                    console.error('Failed to connect:', e);
                    this.scheduleReconnect();
                }
            }
            
            scheduleReconnect() {
                if (this.reconnectAttempts < this.maxReconnectAttempts) {
                    this.reconnectAttempts++;
                    setTimeout(() => this.connect(), this.reconnectDelay);
                    this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);
                }
            }
            
            handleMessage(message) {
                switch (message.type) {
                    case 'initial_data':
                    case 'update':
                        this.updateDashboard(message.data);
                        break;
                    case 'pong':
                        // Handle ping response
                        break;
                }
            }
            
            updateConnectionStatus(connected) {
                const status = document.getElementById('connectionStatus');
                if (connected) {
                    status.textContent = '🟢 Connected';
                    status.className = 'connection-status connected';
                } else {
                    status.textContent = '🔴 Disconnected';
                    status.className = 'connection-status disconnected';
                }
            }
            
            updateDashboard(data) {
                this.updateSystemOverview(data);
                this.updateServices(data.services || []);
                this.updatePerformanceMetrics(data.metrics || {});
                this.updateWatchedFiles(data.metrics?.serviceMetrics?.watchedFiles || {});
                this.updateReloadHistory(data.reloadHistory || []);
            }
            
            updateSystemOverview(data) {
                const uptime = data.systemInfo?.uptime || 0;
                const activeServices = (data.services || []).filter(s => s.status === 'running').length;
                const totalReloads = (data.reloadHistory || []).length;
                
                document.getElementById('uptime').textContent = this.formatUptime(uptime);
                document.getElementById('activeServices').textContent = activeServices;
                document.getElementById('totalReloads').textContent = totalReloads;
                document.getElementById('connectedClients').textContent = data.metrics?.connectedClients || 1;
            }
            
            updateServices(services) {
                const container = document.getElementById('servicesList');
                container.innerHTML = '';
                
                services.forEach(service => {
                    const item = document.createElement('div');
                    item.className = 'service-item';
                    
                    const statusClass = service.status === 'running' ? 'status-running' : 
                                       service.status === 'error' ? 'status-error' : 'status-stopped';
                    
                    item.innerHTML = `
                        <div>
                            <span class="status-indicator \${statusClass}"></span>
                            <span class="service-name">\${service.name}</span>
                        </div>
                        <div class="service-actions">
                            \${service.status === 'running' ? 
                                `<button class="btn btn-primary" onclick="dashboard.restartService('\${service.name}')">Restart</button>
                                 <button class="btn btn-danger" onclick="dashboard.stopService('\${service.name}')">Stop</button>` :
                                `<button class="btn btn-success" onclick="dashboard.startService('\${service.name}')">Start</button>`
                            }
                        </div>
                    `;
                    
                    container.appendChild(item);
                });
            }
            
            updatePerformanceMetrics(metrics) {
                document.getElementById('avgReloadTime').textContent = 
                    metrics.averageReloadTime ? `\${metrics.averageReloadTime}ms` : '--';
                document.getElementById('memoryUsage').textContent = 
                    metrics.memoryUsage ? this.formatBytes(metrics.memoryUsage) : '--';
                document.getElementById('fileWatches').textContent = 
                    metrics.fileWatches || '--';
            }
            
            updateWatchedFiles(watchedFiles) {
                document.getElementById('totalWatchers').textContent = 
                    watchedFiles.totalWatchers || 0;
                document.getElementById('totalWatchPaths').textContent = 
                    watchedFiles.totalWatchPaths || 0;
                document.getElementById('totalPatterns').textContent = 
                    watchedFiles.totalPatterns || 0;
                
                // Store watched files data for details view
                this.watchedFilesData = watchedFiles;
                
                // Update details if currently shown
                if (document.getElementById('watchedFilesDetails').style.display !== 'none') {
                    this.showWatchedFilesDetails();
                }
            }
            
            toggleWatchedFilesDetails() {
                const details = document.getElementById('watchedFilesDetails');
                const toggle = document.getElementById('watchDetailsToggle');
                
                if (details.style.display === 'none') {
                    this.showWatchedFilesDetails();
                    details.style.display = 'block';
                    toggle.textContent = 'Hide Details';
                } else {
                    details.style.display = 'none';
                    toggle.textContent = 'Show Details';
                }
            }
            
            showWatchedFilesDetails() {
                const container = document.getElementById('watchedFilesDetails');
                const data = this.watchedFilesData || {};
                
                let html = '<div style="margin-bottom: 10px;"><strong>Services:</strong></div>';
                
                (data.services || []).forEach(service => {
                    const activeStatus = service.isActive ? '🟢' : '🔴';
                    html += `
                        <div style="margin-bottom: 8px; padding: 5px; background: rgba(255,255,255,0.05); border-radius: 3px;">
                            <div><strong>\${activeStatus} \${service.serviceName}</strong></div>
                            <div style="margin-left: 15px; color: #888;">
                                Watch Paths: \${service.watchPaths.length}<br>
                                Patterns: \${service.matcher.patternCount}<br>
                                Include: \${service.matcher.includePatterns}, Exclude: \${service.matcher.excludePatterns}
                            </div>
                        </div>
                    `;
                });
                
                if (data.summary && Object.keys(data.summary).length > 0) {
                    html += '<div style="margin-top: 10px;"><strong>File Types:</strong></div>';
                    html += '<div style="margin-left: 15px; color: #888;">';
                    for (const [ext, count] of Object.entries(data.summary)) {
                        html += `.\${ext}: \${count} files<br>`;
                    }
                    html += '</div>';
                }
                
                container.innerHTML = html;
            }
            
            updateReloadHistory(events) {
                const container = document.getElementById('reloadHistory');
                container.innerHTML = '';
                
                events.slice(0, 10).forEach(event => {
                    const item = document.createElement('div');
                    item.className = `reload-event \${event.type === 'failed' ? 'failed' : 
                                      event.type === 'hot_restart' ? 'restart' : ''}`;
                    
                    const eventIcon = event.type === 'hot_reload' ? '🔥' :
                                     event.type === 'hot_restart' ? '🔄' : '❌';
                    
                    item.innerHTML = `
                        <div>\${eventIcon} \${event.serviceName} - \${event.type.replace('_', ' ')}</div>
                        <div class="reload-time">\${new Date(event.timestamp).toLocaleTimeString()} 
                             (\${event.duration}ms)</div>
                        \${event.error ? `<div style="color: #ef4444; font-size: 0.8rem;">\${event.error}</div>` : ''}
                    `;
                    
                    container.appendChild(item);
                });
            }
            
            formatUptime(seconds) {
                const hours = Math.floor(seconds / 3600);
                const minutes = Math.floor((seconds % 3600) / 60);
                return `\${hours}h \${minutes}m`;
            }
            
            formatBytes(bytes) {
                if (bytes === 0) return '0 B';
                const k = 1024;
                const sizes = ['B', 'KB', 'MB', 'GB'];
                const i = Math.floor(Math.log(bytes) / Math.log(k));
                return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
            }
            
            async restartService(serviceName) {
                try {
                    await fetch('/api/services/restart', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ serviceName })
                    });
                } catch (e) {
                    console.error('Failed to restart service:', e);
                }
            }
            
            async stopService(serviceName) {
                try {
                    await fetch('/api/services/stop', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ serviceName })
                    });
                } catch (e) {
                    console.error('Failed to stop service:', e);
                }
            }
            
            async startService(serviceName) {
                try {
                    await fetch('/api/services/start', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ serviceName })
                    });
                } catch (e) {
                    console.error('Failed to start service:', e);
                }
            }
        }
        
        // Initialize dashboard
        const dashboard = new DashboardClient();
        
        // Ping every 30 seconds to keep connection alive
        setInterval(() => {
            if (dashboard.isConnected && dashboard.ws) {
                dashboard.ws.send(JSON.stringify({ type: 'ping' }));
            }
        }, 30000);
    </script>
</body>
</html>
    ''';
  }

  /// Gets the running status of the dashboard service (for testing).
  bool get isRunning => _isRunning;

  /// Gets the reload history instance (for testing).
  ReloadHistory get reloadHistory => _reloadHistory;

  /// Gets the metrics collector instance (for testing).
  MetricsCollector get metricsCollector => _metricsCollector;
}
