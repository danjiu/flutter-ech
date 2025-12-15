import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/certificate_service.dart';

/// 证书安装对话框
/// 显示证书安装说明和状态
class CertificateInstallDialog extends StatefulWidget {
  final String certificateType;
  final String certificateData;
  final VoidCallback? onInstalled;

  const CertificateInstallDialog({
    Key? key,
    required this.certificateType,
    required this.certificateData,
    this.onInstalled,
  }) : super(key: key);

  @override
  State<CertificateInstallDialog> createState() => _CertificateInstallDialogState();
}

class _CertificateInstallDialogState extends State<CertificateInstallDialog> {
  bool _isInstalling = false;
  bool _isInstalled = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkCertificateStatus();
  }

  Future<void> _checkCertificateStatus() async {
    final certService = CertificateService.instance;
    if (certService.isCertificateInstalled) {
      setState(() {
        _isInstalled = true;
      });
    }

    // 监听证书状态变化
    certService.certificateStatus.listen((installed) {
      if (mounted) {
        setState(() {
          _isInstalled = installed;
          _isInstalling = false;
        });
        if (installed && widget.onInstalled != null) {
          widget.onInstalled!();
        }
      }
    });
  }

  Future<void> _installCertificate() async {
    setState(() {
      _isInstalling = true;
      _errorMessage = '';
    });

    try {
      final certService = CertificateService.instance;
      final success = await certService.installCertificate(
        certificateData: widget.certificateData,
        certificateType: widget.certificateType,
      );

      if (!success) {
        setState(() {
          _errorMessage = '证书安装失败，请手动安装';
          _isInstalling = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '安装过程中发生错误: $e';
        _isInstalling = false;
      });
    }
  }

  Future<void> _openSettings() async {
    final url = 'App-Prefs:General&path=VPN';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Future<void> _exportCertificate() async {
    final certService = CertificateService.instance;
    final certificateData = await certService.exportCertificate();

    if (certificateData != null) {
      // 复制到剪贴板
      await Clipboard.setData(ClipboardData(text: certificateData));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('证书已复制到剪贴板')),
      );
    }
  }

  Widget _buildInstructions() {
    String instructions;
    Color iconColor;
    IconData iconData;

    if (widget.certificateType == 'CA') {
      instructions = '''CA证书安装步骤：

1. 点击下方"安装证书"按钮
2. Safari将自动打开证书下载页面
3. 点击"允许"下载证书
4. 进入"设置" > "通用" > "VPN与设备管理"
5. 找到并点击"ECH VPN"证书
6. 点击"安装"
7. 输入设备密码确认安装
8. 返回应用继续

注意：安装CA证书将允许应用拦截HTTPS流量''';
      iconColor = Colors.orange;
      iconData = Icons.security;
    } else {
      instructions = '''客户端证书安装步骤：

1. 点击下方"安装证书"按钮
2. Safari将自动打开证书下载页面
3. 点击"允许"下载证书
4. 进入"设置" > "通用" > "VPN与设备管理"
5. 找到并点击下载的证书
6. 点击"安装"
7. 输入设备密码确认安装
8. 返回应用继续''';
      iconColor = Colors.blue;
      iconData = Icons.vpn_key;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(iconData, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                '证书安装说明',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              instructions,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '安装${widget.certificateType == 'CA' ? 'CA' : '客户端'}证书',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isInstalled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '已安装',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInstructions(),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  if (_isInstalled) ...[
                    TextButton.icon(
                      onPressed: _openSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text('打开设置'),
                    ),
                    TextButton.icon(
                      onPressed: _exportCertificate,
                      icon: const Icon(Icons.file_download),
                      label: const Text('导出证书'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('完成'),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: _isInstalling ? null : _installCertificate,
                      icon: _isInstalling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isInstalling ? '安装中...' : '安装证书'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}