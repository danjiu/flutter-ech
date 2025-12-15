import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vpn_service.dart';
import '../models/server_config.dart';
import '../models/vpn_state.dart';
import '../models/connection_stats.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/server_selector.dart';
import '../widgets/connection_stats_widget.dart';
import '../widgets/quick_connect_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VpnService _vpnService = VpnService();
  ServerConfig? _selectedServer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeVpn();
  }

  Future<void> _initializeVpn() async {
    setState(() => _isLoading = true);
    await _vpnService.initialize();

    // 获取当前活动的服务器
    _selectedServer = await _vpnService.currentServer;

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'ECH VPN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 连接状态卡片
                  StreamBuilder<VpnConnectionState>(
                    stream: _vpnService.vpnStateStream,
                    initialData: _vpnService.currentState,
                    builder: (context, snapshot) {
                      return ConnectionStatusCard(
                        state: snapshot.data ?? VpnConnectionState.disconnected,
                        server: _vpnService.currentServer,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 快速连接按钮
                  QuickConnectButton(
                    vpnState: _vpnService.currentState,
                    selectedServer: _selectedServer,
                    onPressed: _handleQuickConnect,
                  ),

                  const SizedBox(height: 24),

                  // 服务器选择器
                  ServerSelector(
                    selectedServer: _selectedServer,
                    onServerSelected: (server) {
                      setState(() {
                        _selectedServer = server;
                      });
                    },
                    onAddServer: () {
                      Navigator.pushNamed(context, '/add_server').then((_) {
                        _refreshServers();
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // 连接统计
                  StreamBuilder<ConnectionStats>(
                    stream: _vpnService.statsStream,
                    initialData: _vpnService.currentStats,
                    builder: (context, snapshot) {
                      return ConnectionStatsWidget(
                        stats: snapshot.data ?? ConnectionStats(),
                        isConnected: _vpnService.currentState.isConnected,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 快捷操作
                  _buildQuickActions(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showConnectionLog,
        icon: const Icon(Icons.article),
        label: const Text('连接日志'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快捷操作',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.security,
                    title: '隐私政策',
                    onTap: () {
                      Navigator.pushNamed(context, '/privacy');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    icon: Icons.import_export,
                    title: '导入/导出',
                    onTap: () {
                      _showImportExportDialog();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue[600]),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleQuickConnect() async {
    if (_selectedServer == null) {
      _showError('请先选择一个服务器');
      return;
    }

    if (_vpnService.currentState.isConnected) {
      await _vpnService.disconnect();
    } else {
      final success = await _vpnService.connect(_selectedServer!);
      if (!success) {
        _showError('连接失败，请检查服务器配置');
      }
    }
  }

  Future<void> _refreshServers() async {
    // 刷新服务器列表
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showConnectionLog() async {
    final log = await _vpnService.getVpnLog();
    if (log != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('连接日志'),
          content: SingleChildScrollView(
            child: SelectableText(
              log,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  void _showImportExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入/导出配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('导出配置'),
              onTap: () {
                Navigator.of(context).pop();
                _exportConfigs();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入配置'),
              onTap: () {
                Navigator.of(context).pop();
                _importConfigs();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportConfigs() async {
    try {
      // TODO: 实现导出功能
      _showError('导出功能开发中');
    } catch (e) {
      _showError('导出失败: $e');
    }
  }

  Future<void> _importConfigs() async {
    try {
      // TODO: 实现导入功能
      _showError('导入功能开发中');
    } catch (e) {
      _showError('导入失败: $e');
    }
  }
}