import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';
import '../utils/logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPackageInfo();
  }

  Future<void> _loadSettings() async {
    final settings = await _storageService.getAppSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _saveSettings() async {
    await _storageService.saveAppSettings(_settings);
    AppLogger.i('Settings saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSection('连接设置', [
                  SwitchListTile(
                    title: const Text('自动连接'),
                    subtitle: const Text('应用启动时自动连接VPN'),
                    value: _settings['auto_connect'] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _settings['auto_connect'] = value;
                      });
                      _saveSettings();
                    },
                  ),
                  ListTile(
                    title: const Text('连接超时'),
                    subtitle: Text('${_settings['connection_timeout'] ?? 30} 秒'),
                    trailing: DropdownButton<int>(
                      value: _settings['connection_timeout'] ?? 30,
                      items: [10, 20, 30, 60, 120].map((seconds) {
                        return DropdownMenuItem(
                          value: seconds,
                          child: Text('$seconds 秒'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _settings['connection_timeout'] = value;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('重试次数'),
                    subtitle: Text('${_settings['retry_count'] ?? 3} 次'),
                    trailing: DropdownButton<int>(
                      value: _settings['retry_count'] ?? 3,
                      items: [1, 3, 5, 10].map((count) {
                        return DropdownMenuItem(
                          value: count,
                          child: Text('$count 次'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _settings['retry_count'] = value;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                ]),
                _buildSection('通知设置', [
                  SwitchListTile(
                    title: const Text('连接通知'),
                    subtitle: const Text('VPN连接状态改变时显示通知'),
                    value: _settings['notifications'] ?? true,
                    onChanged: (value) {
                      setState(() {
                        _settings['notifications'] = value;
                      });
                      _saveSettings();
                    },
                  ),
                ]),
                _buildSection('外观设置', [
                  SwitchListTile(
                    title: const Text('深色模式'),
                    subtitle: const Text('使用深色主题'),
                    value: _settings['dark_mode'] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _settings['dark_mode'] = value;
                      });
                      _saveSettings();
                    },
                  ),
                  ListTile(
                    title: const Text('语言'),
                    subtitle: Text(_getLanguageName(_settings['language'] ?? 'zh_CN')),
                    trailing: DropdownButton<String>(
                      value: _settings['language'] ?? 'zh_CN',
                      items: const [
                        DropdownMenuItem(
                          value: 'zh_CN',
                          child: Text('简体中文'),
                        ),
                        DropdownMenuItem(
                          value: 'en_US',
                          child: Text('English'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _settings['language'] = value;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                ]),
                _buildSection('调试设置', [
                  ListTile(
                    title: const Text('日志级别'),
                    subtitle: Text(_getLogLevelName(_settings['log_level'] ?? 'info')),
                    trailing: DropdownButton<String>(
                      value: _settings['log_level'] ?? 'info',
                      items: const [
                        DropdownMenuItem(value: 'verbose', child: Text('详细')),
                        DropdownMenuItem(value: 'debug', child: Text('调试')),
                        DropdownMenuItem(value: 'info', child: Text('信息')),
                        DropdownMenuItem(value: 'warning', child: Text('警告')),
                        DropdownMenuItem(value: 'error', child: Text('错误')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _settings['log_level'] = value;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('查看日志'),
                    subtitle: const Text('查看应用运行日志'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _showLogs,
                  ),
                ]),
                _buildSection('数据管理', [
                  ListTile(
                    title: const Text('导出配置'),
                    subtitle: const Text('导出服务器配置'),
                    leading: const Icon(Icons.upload_file),
                    onTap: _exportConfigs,
                  ),
                  ListTile(
                    title: const Text('导入配置'),
                    subtitle: const Text('从文件导入配置'),
                    leading: const Icon(Icons.download),
                    onTap: _importConfigs,
                  ),
                  ListTile(
                    title: const Text('清除所有数据'),
                    subtitle: const Text('删除所有配置和连接历史'),
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    onTap: _clearAllData,
                  ),
                ]),
                _buildSection('关于', [
                  ListTile(
                    title: const Text('版本'),
                    subtitle: Text(_packageInfo?.version ?? '1.0.0'),
                    leading: const Icon(Icons.info_outline),
                  ),
                  ListTile(
                    title: const Text('隐私政策'),
                    leading: const Icon(Icons.privacy_tip),
                    onTap: () {
                      Navigator.pushNamed(context, '/privacy');
                    },
                  ),
                  ListTile(
                    title: const Text('开源许可'),
                    leading: const Icon(Icons.code),
                    onTap: _showLicenses,
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'zh_CN':
        return '简体中文';
      case 'en_US':
        return 'English';
      default:
        return code;
    }
  }

  String _getLogLevelName(String level) {
    switch (level) {
      case 'verbose':
        return '详细';
      case 'debug':
        return '调试';
      case 'info':
        return '信息';
      case 'warning':
        return '警告';
      case 'error':
        return '错误';
      default:
        return level;
    }
  }

  void _showLogs() async {
    final vpnService = VpnService();
    final log = await vpnService.getVpnLog();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('应用日志')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                log ?? '暂无日志',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _exportConfigs() async {
    try {
      final json = await _storageService.exportConfigs();
      // TODO: 实现文件保存
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出功能开发中')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  Future<void> _importConfigs() async {
    try {
      // TODO: 实现文件选择
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入功能开发中')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除所有数据'),
        content: const Text('此操作将删除所有服务器配置和连接历史，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _storageService.clearAllData();
              await _loadSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('所有数据已清除'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              '清除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'ECH VPN',
      applicationVersion: _packageInfo?.version ?? '1.0.0',
      applicationLegalese: '基于 Cloudflare Workers ECH 技术的 VPN 客户端',
    );
  }
}