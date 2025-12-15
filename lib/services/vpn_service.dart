import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vpn/flutter_vpn.dart';
import 'package:logger/logger.dart';
import '../models/server_config.dart';
import '../models/vpn_state.dart';
import '../models/connection_stats.dart';
import 'storage_service.dart';
import 'certificate_service.dart';
import 'certificate_platform_channel.dart';
import '../core/proxy_server.dart';

/// FlutterVpnState状态枚举（如果flutter_vpn包没有提供）
enum FlutterVpnState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error
}

class VpnService {
  static const _platform = MethodChannel('ech_flutter_vpn/vpn');
  static final _logger = Logger();
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  final StreamController<VpnConnectionState> _stateController =
      StreamController<VpnConnectionState>.broadcast();
  final StreamController<ConnectionStats> _statsController =
      StreamController<ConnectionStats>.broadcast();

  VpnConnectionState _currentState = VpnConnectionState.disconnected;
  ServerConfig? _currentServer;
  ConnectionStats _currentStats = ConnectionStats();
  Timer? _statsTimer;

  // 使用纯Flutter实现的代理服务器
  ECHProxyServer? _proxyServer;
  StreamSubscription? _statsSubscription;

  Stream<VpnConnectionState> get vpnStateStream => _stateController.stream;
  Stream<ConnectionStats> get statsStream => _statsController.stream;
  VpnConnectionState get currentState => _currentState;
  ServerConfig? get currentServer => _currentServer;
  ConnectionStats get currentStats => _currentStats;

  Future<void> initialize() async {
    try {
      // 注意：新版本的flutter_vpn可能不需要显式初始化
      // 尝试初始化，如果失败则继续

      // 监听 VPN 状态变化
      FlutterVpn.onStateChanged.listen((state) {
        // 根据状态字符串映射到枚举
        FlutterVpnState vpnState;
        switch (state.toLowerCase()) {
          case 'disconnected':
            vpnState = FlutterVpnState.disconnected;
            break;
          case 'connecting':
            vpnState = FlutterVpnState.connecting;
            break;
          case 'connected':
            vpnState = FlutterVpnState.connected;
            break;
          case 'disconnecting':
            vpnState = FlutterVpnState.disconnecting;
            break;
          case 'error':
            vpnState = FlutterVpnState.error;
            break;
          default:
            vpnState = FlutterVpnState.disconnected;
        }
        _updateVpnState(vpnState);
      });

      // 检查当前 VPN 状态
      try {
        final currentState = await FlutterVpn.currentState;
        _updateVpnState(currentState);
      } catch (e) {
        _logger.w('Could not get current VPN state: $e');
      }

      _logger.i('VPN service initialized');
    } catch (e) {
      _logger.e('Failed to initialize VPN service: $e');
    }
  }

  Future<bool> connect(ServerConfig server) async {
    try {
      if (_currentState == VpnConnectionState.connecting ||
          _currentState == VpnConnectionState.connected) {
        _logger.w('VPN is already connected or connecting');
        return false;
      }

      _setState(VpnConnectionState.connecting);
      _currentServer = server;

      // 检查并安装必要的证书
      if (!await _ensureCertificateInstalled()) {
        _logger.e('Certificate installation failed');
        _setState(VpnConnectionState.error);
        return false;
      }

      // 创建代理服务器实例
      _proxyServer = ECHProxyServer(
        serverAddress: server.serverAddress,
        port: 30000, // 本地SOCKS5代理端口
        token: server.token ?? '',
        preferredIp: server.preferredIp ?? '',
        dnsServer: server.dnsServer ?? 'dns.alidns.com/dns-query',
        echDomain: server.echDomain ?? 'cloudflare-ech.com',
        routingMode: _convertRoutingMode(server.routingMode),
      );

      // 监听代理服务器状态
      _statsSubscription = _proxyServer!.statsStream.listen((stats) {
        _handleProxyStats(stats);
      });

      // 启动代理服务器
      final success = await _proxyServer!.start();

      if (!success) {
        _setState(VpnConnectionState.error);
        return false;
      }

      _logger.i('代理服务器已启动，正在连接系统VPN...');

      // 等待代理服务器完全启动
      await Future.delayed(const Duration(seconds: 3));

      // 连接系统VPN到本地代理
      try {
        await FlutterVpn.connect(
          serverAddress: '127.0.0.1',
          username: 'vpn',
          password: '',
          protocol: FlutterVpnProtocol.ikev2,
        );
      } catch (e) {
        _logger.e('FlutterVpn.connect failed: $e');
        _setState(VpnConnectionState.error);
        return false;
      }

      // 更新服务器配置
      await _updateServerConfig(server);

      _logger.i('VPN连接已建立到 ${server.serverAddress}');
      return true;
    } catch (e) {
      _setState(VpnConnectionState.error);
      _logger.e('Failed to connect VPN: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      if (_currentState == VpnConnectionState.disconnected) {
        return;
      }

      _setState(VpnConnectionState.disconnecting);

      // 停止代理服务器
      if (_proxyServer != null) {
        await _proxyServer!.stop();
        _proxyServer = null;
      }
      _statsSubscription?.cancel();

      // 断开 VPN
      await FlutterVpn.disconnect();

      // 停止统计
      _stopStatsTimer();

      // 保存连接统计
      if (_currentServer != null) {
        await _saveConnectionStats(_currentServer!);
      }

      _setState(VpnConnectionState.disconnected);
      _currentServer = null;
      _currentStats = ConnectionStats();

      _logger.i('VPN disconnected');
    } catch (e) {
      _logger.e('Failed to disconnect VPN: $e');
    }
  }

  /// 处理代理服务器统计信息
  void _handleProxyStats(Map<String, dynamic> stats) {
    final status = stats['status'] as String?;

    switch (status) {
      case 'running':
        if (_currentState != VpnConnectionState.connected) {
          _setState(VpnConnectionState.connected);
          _startStatsTimer();
        }
        break;
      case 'error':
        _setState(VpnConnectionState.error);
        _logger.e('代理服务器错误: ${stats['message']}');
        break;
      default:
        break;
    }

    // 更新流量统计
    if (stats['uploadBytes'] != null) {
      _currentStats = ConnectionStats(
        bytesUploaded: stats['uploadBytes'] as int,
        bytesDownloaded: stats['downloadBytes'] as int,
        connectionDuration: stats['duration'] as int,
      );
      _statsController.add(_currentStats);
    }
  }

  Future<void> requestVpnPermission() async {
    try {
      // 请求 VPN 权限（如果需要）
      await _platform.invokeMethod('requestVpnPermission');
    } catch (e) {
      _logger.e('Failed to request VPN permission: $e');
    }
  }

  Future<String?> getVpnLog() async {
    try {
      return await _platform.invokeMethod('getVpnLog');
    } catch (e) {
      _logger.e('Failed to get VPN log: $e');
      return null;
    }
  }

  Future<void> updateRoutingMode(RoutingMode mode) async {
    try {
      await _platform.invokeMethod('updateRoutingMode', {'mode': mode.name});
      if (_currentServer != null) {
        _currentServer = _currentServer!.copyWith(routingMode: mode);
        await StorageService().saveServerConfig(_currentServer!);
      }
    } catch (e) {
      _logger.e('Failed to update routing mode: $e');
    }
  }

  void _updateVpnState(dynamic state) {
    // state可能是字符串或枚举，根据实际情况处理
    String stateStr;
    if (state is String) {
      stateStr = state.toLowerCase();
    } else if (state is FlutterVpnState) {
      stateStr = state.toString().toLowerCase();
    } else {
      stateStr = 'disconnected';
    }

    VpnConnectionState newState;
    switch (stateStr) {
      case 'disconnected':
        newState = VpnConnectionState.disconnected;
        break;
      case 'connecting':
        newState = VpnConnectionState.connecting;
        break;
      case 'connected':
        newState = VpnConnectionState.connected;
        _startStatsTimer();
        break;
      case 'disconnecting':
        newState = VpnConnectionState.disconnecting;
        break;
      case 'error':
        newState = VpnConnectionState.error;
        break;
      default:
        newState = VpnConnectionState.disconnected;
    }

    _setState(newState);
  }

  void _setState(VpnConnectionState state) {
    if (_currentState != state) {
      _currentState = state;
      _stateController.add(state);
      _logger.d('VPN state changed to: ${state.displayName}');
    }
  }

  void _startStatsTimer() {
    _stopStatsTimer();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final stats = await _platform.invokeMethod('getConnectionStats');
        if (stats != null) {
          _currentStats = ConnectionStats.fromJson(stats);
          _statsController.add(_currentStats);
        }
      } catch (e) {
        _logger.e('Failed to get connection stats: $e');
      }
    });
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<Map<String, dynamic>> _buildEchConfig(ServerConfig server) async {
    return {
      'server_address': server.serverAddress,
      'port': server.port,
      'token': server.token,
      'preferred_ip': server.preferredIp,
      'dns_server': server.dnsServer,
      'ech_domain': server.echDomain,
      'routing_mode': server.routingMode.name,
    };
  }

  Future<void> _updateServerConfig(ServerConfig server) async {
    final updatedConfig = server.copyWith(
      isActive: true,
      lastConnected: DateTime.now(),
      connectionCount: server.connectionCount + 1,
    );
    await StorageService().saveServerConfig(updatedConfig);
  }

  Future<void> _saveConnectionStats(ServerConfig server) async {
    // 保存连接统计到本地存储
    final stats = {
      'serverId': server.id,
      'connectedAt': _currentStats.connectedAt?.toIso8601String(),
      'duration': _currentStats.connectionDuration,
      'bytesUploaded': _currentStats.bytesUploaded,
      'bytesDownloaded': _currentStats.bytesDownloaded,
    };
    await StorageService().saveConnectionStats(stats);
  }

  void dispose() {
    _stopStatsTimer();
    _statsSubscription?.cancel();
    if (_proxyServer != null) {
      _proxyServer!.stop();
      _proxyServer = null;
    }
    _stateController.close();
    _statsController.close();
  }

  /// 转换路由模式
  RoutingMode _convertRoutingMode(RoutingMode mode) {
    switch (mode) {
      case RoutingMode.global:
        return RoutingMode.global;
      case RoutingMode.bypassCn:
        return RoutingMode.bypassCn;
      case RoutingMode.none:
        return RoutingMode.none;
    }
  }

  /// 确保证书已安装
  Future<bool> _ensureCertificateInstalled() async {
    final certService = CertificateService.instance;

    // 检查是否已有证书
    if (certService.isCertificateInstalled) {
      _logger.i('Certificate already installed');
      return true;
    }

    // 生成自签名证书
    try {
      final certificates = await certService.generateSelfSignedCertificate(
        commonName: 'ECH VPN Local',
        organization: 'ECH VPN',
        country: 'CN',
        validDays: 365,
      );

      // 安装CA证书
      final certData = certificates['certificate'];
      if (certData != null) {
        final success = await certService.installCertificate(
          certificateData: certData,
          certificateType: 'CA',
        );

        if (success) {
          // 监听安装状态
          await certService.certificateStatus
              .firstWhere((installed) => installed)
              .timeout(const Duration(seconds: 30));
          _logger.i('Certificate installed successfully');
          return true;
        }
      }
    } catch (e) {
      _logger.e('Failed to ensure certificate installation: $e');
    }

    return false;
  }

  /// 安装客户端证书（用于服务端认证）
  Future<bool> installClientCertificate({
    required String certificateData,
    required String privateKey,
    required String password,
  }) async {
    try {
      // 创建PKCS12格式的证书
      final p12Data = await _createPKCS12(
        certificateData: certificateData,
        privateKey: privateKey,
        password: password,
      );

      if (p12Data != null) {
        return await CertificatePlatformChannel.installClientCertificate(
          p12Data,
          password,
        );
      }
    } catch (e) {
      _logger.e('Failed to install client certificate: $e');
    }
    return false;
  }

  /// 创建PKCS12格式证书
  Future<Uint8List?> _createPKCS12({
    required String certificateData,
    required String privateKey,
    required String password,
  }) async {
    // 这里应该使用OpenSSL或类似工具创建PKCS12文件
    // 由于Flutter的限制，需要在原生代码中实现

    // 临时方案：返回测试数据
    return Uint8List.fromList([]);
  }

  /// 移除所有证书
  Future<bool> removeAllCertificates() async {
    try {
      final certService = CertificateService.instance;
      await certService.removeCertificate();
      return await CertificatePlatformChannel.removeAllVPNCertificates();
    } catch (e) {
      _logger.e('Failed to remove all certificates: $e');
      return false;
    }
  }

  /// 获取证书信息
  Future<Map<String, dynamic>?> getCertificateInfo() async {
    try {
      final certificates = await CertificatePlatformChannel.getInstalledCertificates();
      return {
        'installedCertificates': certificates,
        'isInstalled': CertificateService.instance.isCertificateInstalled,
      };
    } catch (e) {
      _logger.e('Failed to get certificate info: $e');
      return null;
    }
  }
}