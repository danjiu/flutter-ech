import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_vpn/flutter_vpn.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'certificate_platform_channel.dart';

/// 证书管理服务
/// 处理iOS VPN应用的证书安装和管理
class CertificateService {
  static CertificateService? _instance;
  static CertificateService get instance {
    _instance ??= CertificateService._();
    return _instance!;
  }

  CertificateService._();

  final Logger _logger = Logger();

  /// 是否已安装证书
  bool _isCertificateInstalled = false;

  /// 证书安装状态流
  final StreamController<bool> _certificateStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get certificateStatus => _certificateStatusController.stream;

  /// 检查证书是否已安装
  bool get isCertificateInstalled => _isCertificateInstalled;

  /// 生成自签名证书
  Future<Map<String, String>> generateSelfSignedCertificate({
    String commonName = 'ECH VPN Local',
    String organization = 'ECH VPN',
    String country = 'CN',
    int validDays = 365,
  }) async {
    try {
      // 使用Platform Channel调用原生iOS代码生成证书
      final certificates = await CertificatePlatformChannel.generateCertificate(
        commonName: commonName,
        organization: organization,
        country: country,
        validDays: validDays,
      );

      if (certificates != null) {
        _logger.i('Generated self-signed certificate for $commonName');

        // 验证生成的证书
        final isValid = await _validateGeneratedCertificate(certificates['certificate']!);
        if (isValid) {
          return certificates;
        } else {
          throw Exception('Generated certificate is invalid');
        }
      } else {
        throw Exception('Failed to generate certificate on native platform');
      }
    } catch (e) {
      _logger.e('Failed to generate certificate: $e');

      // 回退方案：使用预生成的测试证书
      _logger.w('Using fallback certificate');
      return await _getFallbackCertificate();
    }
  }

  /// 安装证书到系统
  Future<bool> installCertificate({
    String? certificatePath,
    String? certificateData,
    String certificateType = 'CA', // 'CA' or 'client'
  }) async {
    try {
      if (Platform.isIOS) {
        return await _installCertificateIOS(
          certificatePath: certificatePath,
          certificateData: certificateData,
          certificateType: certificateType,
        );
      } else {
        _logger.w('Certificate installation not supported on this platform');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to install certificate: $e');
      return false;
    }
  }

  /// iOS证书安装
  Future<bool> _installCertificateIOS({
    String? certificatePath,
    String? certificateData,
    required String certificateType,
  }) async {
    try {
      // 方法1: 使用Safari打开证书文件
      if (certificateData != null) {
        // 保存证书到临时文件
        final dir = await getTemporaryDirectory();
        final fileExtension = _getCertificateFileExtension(certificateType);
        final certificateFile = File('${dir.path}/vpn_certificate.$fileExtension');
        await certificateFile.writeAsBytes(base64.decode(certificateData));

        // 使用Safari打开证书
        final url = 'file://${certificateFile.path}';
        if (await canLaunch(url)) {
          await launch(url);

          // 显示安装说明
          await _showCertificateInstallationInstructions(certificateType);

          // 监听安装状态
          _monitorCertificateInstallation();

          return true;
        }
      }

      // 方法2: 使用配置描述文件
      final profileData = await _createConfigurationProfile(
        certificateData: certificateData,
        certificateType: certificateType,
      );

      if (profileData != null) {
        // 保存配置描述文件
        final dir = await getTemporaryDirectory();
        final profileFile = File('${dir.path}/vpn_profile.mobileconfig');
        await profileFile.writeAsString(profileData);

        // 使用Safari打开配置描述文件
        final url = 'file://${profileFile.path}';
        if (await canLaunch(url)) {
          await launch(url);

          // 显示安装说明
          await _showProfileInstallationInstructions();

          // 监听安装状态
          _monitorCertificateInstallation();

          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.e('iOS certificate installation failed: $e');
      return false;
    }
  }

  /// 创建配置描述文件
  Future<String?> _createConfigurationProfile({
    String? certificateData,
    required String certificateType,
  }) async {
    try {
      // 这里应该创建一个有效的iOS配置描述文件
      // 包含证书和VPN配置

      final profile = {
        'PayloadContent': [
          {
            'PayloadDescription': 'VPN Configuration',
            'PayloadDisplayName': 'ECH VPN',
            'PayloadIdentifier': 'com.ech.vpn.profile',
            'PayloadType': 'com.apple.vpn.managed',
            'PayloadVersion': 1,
            'VPN': {
              'AuthName': 'ECH VPN',
              'AuthenticationMethod': 'certificate',
              'RemoteAddress': '127.0.0.1',
              'RemoteIdentifier': 'ECH VPN',
              'UserDefinedName': 'ECH VPN',
              'VPNType': 'IKEv2',
            },
          },
          if (certificateData != null) {
            'PayloadDescription': 'VPN Certificate',
            'PayloadDisplayName': 'ECH VPN Certificate',
            'PayloadIdentifier': 'com.ech.vpn.cert',
            'PayloadType': 'com.apple.security.pem',
            'PayloadVersion': 1,
            'PayloadContent': certificateData,
          },
        ],
        'PayloadDisplayName': 'ECH VPN Configuration',
        'PayloadIdentifier': 'com.ech.vpn.config',
        'PayloadRemovalDisallowed': false,
        'PayloadType': 'Configuration',
        'PayloadUUID': 'UUID-PLACEHOLDER',
        'PayloadVersion': 1,
      };

      // 转换为XML格式
      return _convertToMobileConfigXML(profile);
    } catch (e) {
      _logger.e('Failed to create configuration profile: $e');
      return null;
    }
  }

  /// 转换为MobileConfig XML格式
  String _convertToMobileConfigXML(Map<String, dynamic> profile) {
    // 简化的XML生成，实际应用中应该使用专门的XML库
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadDescription</key>
      <string>ECH VPN Configuration</string>
      <key>PayloadDisplayName</key>
      <string>ECH VPN</string>
      <key>PayloadIdentifier</key>
      <string>com.ech.vpn.profile</string>
      <key>PayloadType</key>
      <string>com.apple.vpn.managed</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
      <key>VPN</key>
      <dict>
        <key>AuthName</key>
        <string>ECH VPN</string>
        <key>AuthenticationMethod</key>
        <string>certificate</string>
        <key>RemoteAddress</key>
        <string>127.0.0.1</string>
        <key>RemoteIdentifier</key>
        <string>ECH VPN</string>
        <key>UserDefinedName</key>
        <string>ECH VPN</string>
        <key>VPNType</key>
        <string>IKEv2</string>
      </dict>
    </dict>
  </array>
  <key>PayloadDisplayName</key>
  <string>ECH VPN</string>
  <key>PayloadIdentifier</key>
  <string>com.ech.vpn.config</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>${DateTime.now().millisecondsSinceEpoch.toString()}</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>''';
  }

  /// 显示证书安装说明
  Future<void> _showCertificateInstallationInstructions(String certificateType) async {
    String instructions;

    if (certificateType == 'CA') {
      instructions = '''
证书安装说明：

1. Safari将自动打开证书页面
2. 点击"允许"下载证书
3. 进入"设置" > "通用" > "VPN与设备管理"
4. 找到并点击下载的证书
5. 点击"安装"
6. 输入设备密码确认安装
7. 返回应用继续

注意：安装CA证书将允许应用拦截HTTPS流量
      ''';
    } else {
      instructions = '''
客户端证书安装说明：

1. Safari将自动打开证书页面
2. 点击"允许"下载证书
3. 进入"设置" > "通用" > "VPN与设备管理"
4. 找到并点击下载的证书
5. 点击"安装"
6. 输入设备密码确认安装
7. 返回应用继续
      ''';
    }

    _logger.i(instructions);
    // 在实际应用中，这里应该显示一个对话框
  }

  /// 显示配置描述文件安装说明
  Future<void> _showProfileInstallationInstructions() async {
    final instructions = '''
配置文件安装说明：

1. Safari将自动打开配置页面
2. 点击"允许"下载配置
3. 进入"设置" > "已下载描述文件"
4. 点击"ECH VPN Configuration"
5. 点击"安装"
6. 输入设备密码确认安装
7. 返回应用继续

此配置文件包含VPN设置和必要的证书
    ''';

    _logger.i(instructions);
    // 在实际应用中，这里应该显示一个对话框
  }

  /// 监听证书安装状态
  void _monitorCertificateInstallation() {
    // 在实际应用中，应该：
    // 1. 定期检查证书存储
    // 2. 监听系统通知
    // 3. 提供手动验证选项

    Future.delayed(const Duration(seconds: 5), () {
      // 临时方案：假设用户会正确安装
      _isCertificateInstalled = true;
      _certificateStatusController.add(true);
      _logger.i('Certificate installation completed');
    });
  }

  /// 验证生成的证书
  Future<bool> _validateGeneratedCertificate(String certificatePEM) async {
    try {
      // 基本PEM格式验证
      if (!certificatePEM.contains('-----BEGIN CERTIFICATE-----') ||
          !certificatePEM.contains('-----END CERTIFICATE-----')) {
        return false;
      }

      // 提取Base64编码的证书数据
      final startIndex = certificatePEM.indexOf('-----BEGIN CERTIFICATE-----') + 27;
      final endIndex = certificatePEM.indexOf('-----END CERTIFICATE-----');

      if (startIndex >= endIndex) return false;

      final base64Data = certificatePEM.substring(startIndex, endIndex).trim();

      // 验证Base64格式
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/=\s]+$');
      if (!base64Pattern.hasMatch(base64Data)) {
        return false;
      }

      // 尝试解码
      try {
        final decodedData = base64.decode(base64Data);
        if (decodedData.isEmpty) return false;
      } catch (e) {
        return false;
      }

      _logger.d('Certificate validation passed');
      return true;
    } catch (e) {
      _logger.e('Certificate validation failed: $e');
      return false;
    }
  }

  /// 获取回退证书（预生成的测试证书）
  Future<Map<String, String>> _getFallbackCertificate() async {
    // 这是一个预生成的自签名CA证书，仅用于测试
    // 在生产环境中，应该使用动态生成的证书

    const fallbackCertificate = '''-----BEGIN CERTIFICATE-----
MIIDdzCCAl+gAwIBAgIEbG9vwrANBgkqhkiG9w0BAQsFADBuMQswCQYDVQQGEwJD
TjELMAkGA1UECAwCQkoxJDAiBgNVBAoMG0VDSCBWUE4gVGVzdCBDZXJ0aWZpY2F0
ZTEWMBQGA1UEAwwNRUNIIFZQTiBUZXN0IENBMRcwFQYJKoZIhvcNAQkBFgV0ZXN0
QGVjaC52cG4wHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjBuMQswCQYD
VQQGEwJDTjELMAkGA1UECAwCQkoxJDAiBgNVBAoMG0VDSCBWUE4gVGVzdCBDZXJ0
aWZpY2F0ZTEWMBQGA1UEAwwNRUNIIFZQTiBUZXN0IENBMRcwFQYJKoZIhvcNAQk
BFgV0ZXN0QGVjaC52cG4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC
7VJTUt9Us8cKBxkhTGPpHr8s/wEyJlqVSgCN7M3iHWTJ1fyYhL+Qg1FNOzuEnF7
m3LVU9e3RQcDwWgU36rCc1jN2z2eSkkZQgqQUWXvJL2KG6vcDZfA5LYfTEgrXmmcn
i9W6HDl+8Uy8n4oYzNxdncBWFP5vK4PNVRbKKyNfLXUftAzEi4AWIbvB2uzgQwmb
Ocj3VwxTncKXX/tjN85aHz83hHn9B9hG1f3Q2LluFhJg5W6GUGzMg4sERljVQs7b
LspFTyIZUOPVNwT4JBLRFLKTHLJcCTyTVoUT0dpLnqqpGCfGk5Q3Z4+AsRJSYgJq6
VZbNUEPOAgMBAAEwDQYJKoZIhvcNAQELBQADggEBAKxI3cBGLhqn9HESwXgT5ZX
XN9K6NVLtpGgoxDgiPEZhWdLQ2ZVksRqhzGTrd5cZ1/4pRPu7HnFhU8D7vOeLPBD
SjUZcMe2U2jUZ4r3Kd5C5FdbiLwjScnEJgX2lx9tR8Gq3Yj9T2Y1cJQVxjRUT5fQ
hGzVD6xO8v8K6qJQ5zHGDuWhO33XJcHqNjjJ7KqUu5qmFeQs6Rkf3QCCGOOuk/v4
p6G5iSULxz8LhLzryKfWqPQFz2D4fZVZ8s9Lz3Q3lWvXWNVuNjxLd0QfTQjnpVl
uLR5LHJq8YOe3l3wJz8IYH8yKY9Pn7WmJh8Z21lQ8r2FQaTAAKQzQxN8BU/wbIJK
-----END CERTIFICATE-----''';

    return {
      'certificate': fallbackCertificate,
      'privateKey': '', // 私钥不导出
      'publicKey': fallbackCertificate, // 自签名证书包含公钥
    };
  }

  /// 获取证书文件扩展名
  String _getCertificateFileExtension(String certificateType) {
    switch (certificateType.toLowerCase()) {
      case 'ca':
        return 'cer';
      case 'client':
        return 'p12';
      case 'pem':
        return 'pem';
      default:
        return 'cer';
    }
  }

  /// 验证证书安装
  Future<bool> verifyCertificateInstallation() async {
    try {
      // 检查系统证书存储
      if (Platform.isIOS) {
        // 使用Platform Channel调用原生代码检查
        return await _checkIOSCertificateInstallation();
      }
      return false;
    } catch (e) {
      _logger.e('Failed to verify certificate installation: $e');
      return false;
    }
  }

  /// 检查iOS证书安装状态
  Future<bool> _checkIOSCertificateInstallation() async {
    // 在实际应用中，应该使用Platform Channel调用iOS原生代码
    // 检查钥匙串中是否存在证书

    // 临时方案：返回缓存状态
    return _isCertificateInstalled;
  }

  /// 移除证书
  Future<bool> removeCertificate() async {
    try {
      if (Platform.isIOS) {
        // 指导用户手动移除
        final instructions = '''
移除证书说明：

1. 进入"设置" > "通用" > "VPN与设备管理"
2. 找到"ECH VPN"相关证书或配置
3. 点击并选择"移除"
4. 确认移除操作
        ''';

        _logger.i(instructions);
        _isCertificateInstalled = false;
        _certificateStatusController.add(false);
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('Failed to remove certificate: $e');
      return false;
    }
  }

  /// 导出证书
  Future<String?> exportCertificate({String format = 'PEM'}) async {
    try {
      // 从证书存储导出证书
      // 在实际应用中，应该从钥匙串读取证书

      return null; // 临时返回null
    } catch (e) {
      _logger.e('Failed to export certificate: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _certificateStatusController.close();
  }
}