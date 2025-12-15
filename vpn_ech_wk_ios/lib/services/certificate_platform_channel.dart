import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// 证书Platform Channel
/// 与原生iOS代码通信进行证书操作
class CertificatePlatformChannel {
  static const MethodChannel _channel = MethodChannel('ech_vpn/certificate');
  static final Logger _logger = Logger();

  /// 安装CA证书
  static Future<bool> installCACertificate(Uint8List certificateData) async {
    try {
      final result = await _channel.invokeMethod<bool>('installCACertificate', {
        'certificateData': certificateData,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to install CA certificate: ${e.message}');
      return false;
    }
  }

  /// 安装客户端证书
  static Future<bool> installClientCertificate(Uint8List p12Data, String password) async {
    try {
      final result = await _channel.invokeMethod<bool>('installClientCertificate', {
        'p12Data': p12Data,
        'password': password,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to install client certificate: ${e.message}');
      return false;
    }
  }

  /// 检查证书是否已安装
  static Future<bool> isCertificateInstalled(String commonName) async {
    try {
      final result = await _channel.invokeMethod<bool>('isCertificateInstalled', {
        'commonName': commonName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to check certificate installation: ${e.message}');
      return false;
    }
  }

  /// 获取所有已安装的证书
  static Future<List<String>> getInstalledCertificates() async {
    try {
      final result = await _channel.invokeListMethod<String>('getInstalledCertificates');
      return result ?? [];
    } on PlatformException catch (e) {
      _logger.e('Failed to get installed certificates: ${e.message}');
      return [];
    }
  }

  /// 移除证书
  static Future<bool> removeCertificate(String commonName) async {
    try {
      final result = await _channel.invokeMethod<bool>('removeCertificate', {
        'commonName': commonName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to remove certificate: ${e.message}');
      return false;
    }
  }

  /// 移除所有VPN相关证书
  static Future<bool> removeAllVPNCertificates() async {
    try {
      final result = await _channel.invokeMethod<bool>('removeAllVPNCertificates');
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to remove all VPN certificates: ${e.message}');
      return false;
    }
  }

  /// 创建VPN配置描述文件
  static Future<Uint8List?> createVPNProfile(
    String serverAddress,
    Uint8List? certificateData,
  ) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('createVPNProfile', {
        'serverAddress': serverAddress,
        'certificateData': certificateData,
      });
      return result;
    } on PlatformException catch (e) {
      _logger.e('Failed to create VPN profile: ${e.message}');
      return null;
    }
  }

  /// 导出证书
  static Future<Uint8List?> exportCertificate(String commonName, String format) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('exportCertificate', {
        'commonName': commonName,
        'format': format, // 'PEM', 'DER', 'P12'
      });
      return result;
    } on PlatformException catch (e) {
      _logger.e('Failed to export certificate: ${e.message}');
      return null;
    }
  }

  /// 验证证书链
  static Future<bool> verifyCertificateChain(Uint8List certificateData) async {
    try {
      final result = await _channel.invokeMethod<bool>('verifyCertificateChain', {
        'certificateData': certificateData,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      _logger.e('Failed to verify certificate chain: ${e.message}');
      return false;
    }
  }

  /// 生成自签名证书
  static Future<Map<String, String>?> generateCertificate({
    required String commonName,
    required String organization,
    required String country,
    int validDays = 365,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, String>('generateCertificate', {
        'commonName': commonName,
        'organization': organization,
        'country': country,
        'validDays': validDays,
      });
      return result;
    } on PlatformException catch (e) {
      _logger.e('Failed to generate certificate: ${e.message}');
      return null;
    }
  }

  /// 获取证书信息
  static Future<Map<String, dynamic>?> getCertificateInfo(String commonName) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getCertificateInfo', {
        'commonName': commonName,
      });
      return result;
    } on PlatformException catch (e) {
      _logger.e('Failed to get certificate info: ${e.message}');
      return null;
    }
  }

  /// 检查证书有效性
  static Future<Map<String, dynamic>?> checkCertificateValidity(String commonName) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('checkCertificateValidity', {
        'commonName': commonName,
      });
      return result;
    } on PlatformException catch (e) {
      _logger.e('Failed to check certificate validity: ${e.message}');
      return null;
    }
  }
}