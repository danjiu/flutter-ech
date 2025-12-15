import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/server_config.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

class ServerConfigScreen extends StatefulWidget {
  final ServerConfig? server;

  const ServerConfigScreen({Key? key, this.server}) : super(key: key);

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _serverAddressController = TextEditingController();
  final _portController = TextEditingController(text: '443');
  final _tokenController = TextEditingController();
  final _preferredIpController = TextEditingController();
  final _dnsController = TextEditingController(text: 'dns.alidns.com/dns-query');
  final _echDomainController = TextEditingController(text: 'cloudflare-ech.com');

  RoutingMode _routingMode = RoutingMode.global;
  bool _isAdvancedExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.server != null) {
      _loadServerConfig();
    }
  }

  void _loadServerConfig() {
    final server = widget.server!;
    _nameController.text = server.name;
    _serverAddressController.text = server.serverAddress;
    _portController.text = server.port.toString();
    _tokenController.text = server.token ?? '';
    _preferredIpController.text = server.preferredIp ?? '';
    _dnsController.text = server.dnsServer ?? 'dns.alidns.com/dns-query';
    _echDomainController.text = server.echDomain ?? 'cloudflare-ech.com';
    _routingMode = server.routingMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverAddressController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _preferredIpController.dispose();
    _dnsController.dispose();
    _echDomainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.server != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑服务器' : '添加服务器'),
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 基本信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '基本信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '服务器名称',
                        hintText: '例如: 我的VPN服务器',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入服务器名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serverAddressController,
                      decoration: const InputDecoration(
                        labelText: '服务器地址',
                        hintText: '例如: your-worker.workers.dev',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入服务器地址';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: '端口',
                              hintText: '443',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入端口号';
                              }
                              final port = int.tryParse(value);
                              if (port == null || port < 1 || port > 65535) {
                                return '请输入有效的端口号 (1-65535)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<RoutingMode>(
                            value: _routingMode,
                            decoration: const InputDecoration(
                              labelText: '路由模式',
                              border: OutlineInputBorder(),
                            ),
                            items: RoutingMode.values.map((mode) {
                              return DropdownMenuItem(
                                value: mode,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(mode.displayName),
                                    Text(
                                      mode.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _routingMode = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: '访问令牌 (可选)',
                        hintText: '如果服务器需要认证，请输入令牌',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 高级设置
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      '高级设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(
                      _isAdvancedExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onTap: () {
                      setState(() {
                        _isAdvancedExpanded = !_isAdvancedExpanded;
                      });
                    },
                  ),
                  if (_isAdvancedExpanded)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _preferredIpController,
                            decoration: const InputDecoration(
                              labelText: '优选IP (可选)',
                              hintText: '直接连接到此IP，跳过DNS解析',
                              border: OutlineInputBorder(),
                              helperText: '例如: visa.com 或 1.2.3.4',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dnsController,
                            decoration: const InputDecoration(
                              labelText: 'DNS over HTTPS 服务器',
                              hintText: '用于ECH查询的DoH服务器',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _echDomainController,
                            decoration: const InputDecoration(
                              labelText: 'ECH查询域名',
                              hintText: '用于获取ECH配置的域名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveConfig,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditing ? '更新服务器' : '添加服务器'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final storageService = StorageService();
      final port = int.parse(_portController.text);

      final serverConfig = ServerConfig(
        id: widget.server?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        serverAddress: _serverAddressController.text.trim(),
        port: port,
        token: _tokenController.text.trim().isEmpty
            ? null
            : _tokenController.text.trim(),
        preferredIp: _preferredIpController.text.trim().isEmpty
            ? null
            : _preferredIpController.text.trim(),
        dnsServer: _dnsController.text.trim().isEmpty
            ? 'dns.alidns.com/dns-query'
            : _dnsController.text.trim(),
        echDomain: _echDomainController.text.trim().isEmpty
            ? 'cloudflare-ech.com'
            : _echDomainController.text.trim(),
        routingMode: _routingMode,
        isActive: widget.server?.isActive ?? false,
        createdAt: widget.server?.createdAt ?? DateTime.now(),
        lastConnected: widget.server?.lastConnected,
        connectionCount: widget.server?.connectionCount ?? 0,
      );

      await storageService.saveServerConfig(serverConfig);

      // 如果设置了Token，也保存到安全存储
      if (serverConfig.token != null) {
        await storageService.saveToken(serverConfig.id, serverConfig.token!);
      }

      AppLogger.i('Server config saved: ${serverConfig.name}');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? '服务器已更新' : '服务器已添加'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Failed to save server config: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}