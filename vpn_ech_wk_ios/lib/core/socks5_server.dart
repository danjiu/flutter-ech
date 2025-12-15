import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// 导入RoutingMode从models
import '../models/server_config.dart';

/// SOCKS5代理服务器实现
class SOCKS5Server {
  late ServerSocket _server;
  bool _isRunning = false;
  final int port;
  final ECHClient _echClient;
  final RoutingMode _routingMode;

  // 连接统计
  int _totalConnections = 0;
  int _activeConnections = 0;
  int64 _bytesTransferred = 0;

  SOCKS5Server({
    required this.port,
    required this._echClient,
    this._routingMode = RoutingMode.global,
  });

  /// 启动SOCKS5服务器
  Future<void> start() async {
    if (_isRunning) return;

    try {
      _server = await ServerSocket.bind('127.0.0.1', port);
      _isRunning = true;
      print('SOCKS5 server started on port $port');

      // 监听连接
      await for (Socket socket in _server) {
        _totalConnections++;
        _activeConnections++;
        _handleConnection(socket);
      }
    } catch (e) {
      print('Failed to start SOCKS5 server: $e');
      _isRunning = false;
    }
  }

  /// 停止SOCKS5服务器
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    await _server.close();
    print('SOCKS5 server stopped');
  }

  /// 处理客户端连接
  Future<void> _handleConnection(Socket client) async {
    try {
      // SOCKS5握手
      if (!await _handleSocks5Handshake(client)) {
        client.close();
        return;
      }

      // 处理连接请求
      final target = await _handleSocks5Request(client);
      if (target == null) {
        client.close();
        return;
      }

      // 连接到目标服务器
      final targetSocket = await _connectToTarget(target);
      if (targetSocket == null) {
        _sendSocks5Response(client, 0x01); // General failure
        client.close();
        return;
      }

      // 发送成功响应
      _sendSocks5Response(client, 0x00); // Success

      // 开始数据转发
      await _forwardData(client, targetSocket);
    } catch (e) {
      print('Error handling connection: $e');
    } finally {
      client.close();
      _activeConnections--;
    }
  }

  /// SOCKS5握手
  Future<bool> _handleSocks5Handshake(Socket socket) async {
    try {
      final data = await socket.read(257).timeout(Duration(seconds: 5));
      if (data.isEmpty || data[0] != 0x05) return false;

      // 响应：选择无认证方法
      socket.add([0x05, 0x00]);
      await socket.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 处理SOCKS5连接请求
  Future<String?> _handleSocks5Request(Socket socket) async {
    try {
      final data = await socket.read(262).timeout(Duration(seconds: 5));
      if (data.length < 7 || data[0] != 0x05 || data[1] != 0x01) {
        return null;
      }

      final addrType = data[3];
      String target;

      switch (addrType) {
        case 0x01: // IPv4
          if (data.length < 10) return null;
          final ip = '${data[4]}.${data[5]}.${data[6]}.${data[7]}';
          final port = (data[8] << 8) | data[9];
          target = '$ip:$port';
          break;

        case 0x03: // 域名
          if (data.length < 7) return null;
          final domainLen = data[4];
          if (data.length < 5 + domainLen + 2) return null;
          final domain = String.fromCharCodes(data, 5, 5 + domainLen);
          final port = (data[5 + domainLen] << 8) | data[6 + domainLen];
          target = '$domain:$port';
          break;

        case 0x04: // IPv6
          if (data.length < 22) return null;
          final ipBytes = data.sublist(4, 20);
          final ip = ipBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
          final port = (data[20] << 8) | data[21];
          target = '[$ip]:$port';
          break;

        default:
          return null;
      }

      return target;
    } catch (e) {
      return null;
    }
  }

  /// 发送SOCKS5响应
  void _sendSocks5Response(Socket socket, int status) {
    final response = Uint8List(10);
    response[0] = 0x05; // SOCKS version
    response[1] = status; // Status
    response[2] = 0x00; // Reserved
    response[3] = 0x01; // ATYP = IPv4
    // 填充地址字段（本地回环）
    response[4] = 0x7F;
    response[5] = 0x00;
    response[6] = 0x00;
    response[7] = 0x01;
    // 填充端口字段
    response[8] = 0x00;
    response[9] = 0x00;

    socket.add(response);
    socket.flush();
  }

  /// 连接到目标服务器
  Future<Socket?> _connectToTarget(String target) async {
    try {
      // 解析目标地址
      final host = target.split(':')[0];
      final port = int.parse(target.split(':')[1]);

      // 检查路由模式
      if (_routingMode == RoutingMode.bypassCn && await _isChinaIP(host)) {
        // 直连
        return await Socket.connect(host, port, timeout: Duration(seconds: 10));
      }

      // 通过ECH代理连接
      return await _connectViaEch(host, port);
    } catch (e) {
      print('Failed to connect to target $target: $e');
      return null;
    }
  }

  /// 通过ECH代理连接
  Future<Socket?> _connectViaEch(String host, int port) async {
    try {
      // 如果配置了优选IP，使用IP直连
      if (_echClient.preferredIp != null) {
        return await Socket.connect(_echClient.preferredIp!, port,
            timeout: Duration(seconds: 10));
      }

      // 否则使用域名连接（ECH会在TLS握手时自动处理）
      return await Socket.connect(host, port, timeout: Duration(seconds: 10));
    } catch (e) {
      print('Failed to connect via ECH: $e');
      return null;
    }
  }

  /// 转发数据
  Future<void> _forwardData(Socket client, Socket target) async {
    final completer = Completer<void>();
    int bytesTransferred = 0;

    // 客户端到目标
    final clientToTarget = client.listen((data) {
      target.add(data);
      target.flush();
      bytesTransferred += data.length;
      _bytesTransferred += data.length;
    });

    // 目标到客户端
    final targetToClient = target.listen((data) {
      client.add(data);
      client.flush();
      bytesTransferred += data.length;
      _bytesTransferred += data.length;
    });

    // 监听连接关闭
    client.done.then((_) {
      completer.complete();
      clientToTarget.cancel();
      targetToClient.cancel();
    });

    target.done.then((_) {
      completer.complete();
      clientToTarget.cancel();
      targetToClient.cancel();
    });

    // 超时处理（30分钟）
    await completer.future.timeout(Duration(minutes: 30),
        onTimeout: () {
      clientToTarget.cancel();
      targetToClient.cancel();
    });

    target.close();
  }

  /// 检查是否为中国IP（简化版）
  Future<bool> _isChinaIP(String host) async {
    try {
      // 尝试解析域名
      final addresses = await InternetAddress.lookup(host);
      for (final addr in addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          final ip = addr.address;
          // 简单的中国IP段判断
          // 实际应用中应该加载完整的中国IP列表
          if (_isChinaIPSimple(ip)) {
            return true;
          }
        }
      }
    } catch (e) {
      print('Failed to lookup IP: $e');
    }
    return false;
  }

  /// 简单的中国IP判断（仅用于演示）
  bool _isChinaIPSimple(String ip) {
    // 这里应该使用完整的IP段数据库
    // 以下是示例：
    final parts = ip.split('.').map(int.parse).toList();

    // 电信段示例
    if (parts[0] == 117 && parts[1] >= 128 && parts[1] <= 255) {
      return true;
    }

    // 联通段示例
    if (parts[0] == 61 && parts[1] >= 128 && parts[1] <= 255) {
      return true;
    }

    return false;
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return {
      'totalConnections': _totalConnections,
      'activeConnections': _activeConnections,
      'bytesTransferred': _bytesTransferred,
      'isRunning': _isRunning,
    };
  }
}

enum RoutingMode {
  global,
  bypassCn,
  none,
}