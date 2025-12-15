import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/vpn_state.dart';
import '../models/server_config.dart';

class ConnectionStatusCard extends StatelessWidget {
  final VpnConnectionState state;
  final ServerConfig? server;

  const ConnectionStatusCard({
    Key? key,
    required this.state,
    this.server,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final statusText = _getStatusText();

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isTransitioning)
                  SpinKitThreeBounce(
                    color: color,
                    size: 24,
                  )
                else
                  Icon(
                    icon,
                    color: color,
                    size: 48,
                  ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (server != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        server!.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        server!.serverAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDetails() {
    switch (state) {
      case VpnConnectionState.connected:
        return Column(
          children: [
            _buildStatusRow('保护已启用', '您的网络连接已加密'),
            _buildStatusRow('服务器', server?.serverAddress ?? '未知'),
            _buildStatusRow('路由模式', server?.routingMode.displayName ?? '全局代理'),
          ],
        );
      case VpnConnectionState.connecting:
        return _buildStatusRow('正在连接', '请稍候...');
      case VpnConnectionState.disconnecting:
        return _buildStatusRow('正在断开', '请稍候...');
      case VpnConnectionState.error:
        return _buildStatusRow('连接失败', '请检查网络设置');
      case VpnConnectionState.disconnected:
      default:
        return _buildStatusRow('未连接', '点击连接按钮开始使用');
    }
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.green[600],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (state) {
      case VpnConnectionState.connected:
        return Colors.green;
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
        return Colors.blue;
      case VpnConnectionState.error:
        return Colors.red;
      case VpnConnectionState.disconnected:
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (state) {
      case VpnConnectionState.connected:
        return Icons.security;
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
        return Icons.sync;
      case VpnConnectionState.error:
        return Icons.error_outline;
      case VpnConnectionState.disconnected:
      default:
        return Icons.security_outlined;
    }
  }

  String _getStatusText() {
    switch (state) {
      case VpnConnectionState.connected:
        return '已连接';
      case VpnConnectionState.connecting:
        return '连接中';
      case VpnConnectionState.disconnecting:
        return '断开中';
      case VpnConnectionState.error:
        return '连接错误';
      case VpnConnectionState.disconnected:
      default:
        return '未连接';
    }
  }
}