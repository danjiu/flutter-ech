import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ech_client.dart';
import 'china_ip_database.dart';
import 'socks5_server.dart';

// 从models导入RoutingMode
import '../models/server_config.dart';

// 用于不等待Future完成
void unawaited(Future<void> future) {
  // Intentionally not awaiting the future
}

/// ECH代理服务器
/// 整合了ECH客户端、SOCKS5服务器和分流规则
class ECHProxyServer {
  final String serverAddress;
  final int port;
  final String? token;
  final String? preferredIp;
  final String dnsServer;
  final String echDomain;
  final RoutingMode routingMode;

  late final ECHClient _echClient;
  late final SOCKS5Server _socksServer;
  final ChinaIPDatabase _ipDatabase = ChinaIPDatabase.instance;

  bool _isRunning = false;
  DateTime? _startTime;
  int _totalUploadBytes = 0;
  int _totalDownloadBytes = 0;

  // 统计流控制器
  final StreamController<Map<String, dynamic>> _statsController =
      StreamController.broadcast();

  ECHProxyServer({
    required this.serverAddress,
    this.port = 30000,
    this.token,
    this.preferredIp,
    this.dnsServer = 'dns.alidns.com/dns-query',
    this.echDomain = 'cloudflare-ech.com',
    this.routingMode = RoutingMode.global,
  }) {
    _echClient = ECHClient(
      serverAddress: serverAddress,
      dnsServer: dnsServer,
      echDomain: echDomain,
      token: token,
      preferredIp: preferredIp,
    );

    _socksServer = SOCKS5Server(
      port: port,
      echClient: _echClient,
      routingMode: routingMode,
    );
  }

  /// 获取统计信息流
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  /// 启动代理服务器
  Future<bool> start() async {
    if (_isRunning) {
      print('Proxy server is already running');
      return true;
    }

    try {
      print('Starting ECH proxy server...');
      print('Server: $serverAddress');
      print('Port: $port');
      print('Routing mode: ${routingMode.name}');

      // 初始化中国IP数据库
      await _ipDatabase.initialize();

      // 启动SOCKS5服务器
      unawaited(_socksServer.start());

      _isRunning = true;
      _startTime = DateTime.now();

      // 定期更新统计信息
      _startStatsUpdater();

      print('ECH proxy server started successfully');

      // 发送启动状态
      _statsController.add({
        'status': 'running',
        'message': '代理服务器已启动',
        'startTime': _startTime?.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Failed to start proxy server: $e');
      _statsController.add({
        'status': 'error',
        'message': '启动失败: $e',
      });
      return false;
    }
  }

  /// 停止代理服务器
  Future<void> stop() async {
    if (!_isRunning) return;

    print('Stopping ECH proxy server...');
    _isRunning = false;

    await _socksServer.stop();
    _statsController.close();

    print('ECH proxy server stopped');
  }

  /// 判断是否在中国（使用缓存的IP数据库）
  Future<bool> _isChinaIP(String host) async {
    return _ipDatabase.isChineseIP(host);
  }

  /// 通过Cloudflare Workers转发请求
  Future<http.Response> _forwardViaWorker(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      // 构建请求URL
      final workerUrl = 'https://$serverAddress/$method';

      // 准备请求头
      final requestHeaders = {
        'Content-Type': 'application/json',
        'X-Target-URL': url,
        'X-Method': method,
        ...?headers,
      };

      // 添加认证token（如果有）
      if (token != null && token!.isNotEmpty) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      // 发送请求到Workers
      final response = await http.post(
        Uri.parse(workerUrl),
        headers: requestHeaders,
        body: body != null ? json.encode(body) : null,
      );

      // 统计流量
      if (response.request != null) {
        _totalUploadBytes += response.request!.contentLength ?? 0;
      }
      _totalDownloadBytes += response.contentLength ?? 0;

      return response;
    } catch (e) {
      print('Failed to forward via Workers: $e');
      rethrow;
    }
  }

  /// 创建安全的HTTP客户端（通过代理）
  http.Client createProxiedHttpClient() {
    return http.Client();
  }

  /// 启动统计信息更新器
  void _startStatsUpdater() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      // 获取SOCKS5服务器统计
      final socksStats = _socksServer.getStats();

      // 计算运行时长
      final duration = _startTime != null
          ? DateTime.now().difference(_startTime!).inSeconds
          : 0;

      // 发送统计信息
      _statsController.add({
        'status': 'running',
        'duration': duration,
        'totalConnections': socksStats['totalConnections'],
        'activeConnections': socksStats['activeConnections'],
        'bytesTransferred': socksStats['bytesTransferred'],
        'uploadBytes': _totalUploadBytes,
        'downloadBytes': _totalDownloadBytes,
        'routingMode': routingMode.name,
      });
    });
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      // 尝试连接到服务器
      final testUrl = Uri.parse('https://$serverAddress');
      final request = await http.get(testUrl).timeout(Duration(seconds: 10));

      return request.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  /// 获取当前状态
  Map<String, dynamic> getStatus() {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;

    return {
      'isRunning': _isRunning,
      'duration': duration,
      'serverAddress': serverAddress,
      'port': port,
      'routingMode': routingMode.name,
      'ipDatabaseInitialized': _ipDatabase.isInitialized,
    };
  }
}
