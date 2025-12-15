import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私政策'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('隐私政策'),
            _buildSectionContent('''
本应用非常重视用户隐私。本隐私政策说明了我们如何收集、使用和保护您的信息。

使用本应用即表示您同意本政策中描述的做法。
'''),

            _buildSectionTitle('1. 信息收集'),
            _buildSectionContent('''
本应用可能收集以下信息：

• 连接日志：用于记录VPN连接状态和统计信息
• 性能数据：用于优化应用性能
• 错误报告：用于诊断和修复问题

我们不会收集您的个人身份信息、浏览历史或传输内容。
'''),

            _buildSectionTitle('2. 信息使用'),
            _buildSectionContent('''
收集的信息仅用于：

• 提供VPN服务
• 改善用户体验
• 诊断技术问题
• 确保服务安全

我们不会将您的信息出售给第三方。
'''),

            _buildSectionTitle('3. 数据存储'),
            _buildSectionContent('''
• 本地存储：所有配置和历史记录都存储在您的设备上
• 加密保护：敏感数据（如访问令牌）使用系统安全存储进行加密
• 云端同步：不支持云端同步，您的数据完全本地化
'''),

            _buildSectionTitle('4. ECH技术说明'),
            _buildSectionContent('''
本应用使用TLS 1.3的ECH（Encrypted Client Hello）技术：

• 加密SNI信息，保护您的隐私
• 防止网络窥探
• 符合最新的隐私保护标准
'''),

            _buildSectionTitle('5. 第三方服务'),
            _buildSectionContent('''
本应用可能使用以下第三方服务：

• Cloudflare Workers：提供VPN代理服务
• DoH提供商：提供安全DNS解析
• Flutter框架：应用开发框架

请注意，这些服务有各自的隐私政策。
'''),

            _buildSectionTitle('6. 您的权利'),
            _buildSectionContent(''''
您有权：

• 访问您的数据
• 修改或删除您的配置
• 导出您的配置
• 完全清除应用数据
• 随时停止使用本应用
'''),

            _buildSectionTitle('7. 联系我们'),
            _buildSectionContent('''
如果您对本隐私政策有任何疑问，请通过以下方式联系我们：

• 邮箱：support@example.com
• GitHub：https://github.com/yourusername/ech-flutter-vpn

我们会在收到您的反馈后尽快回复。
'''),

            _buildSectionTitle('8. 政策更新'),
            _buildSectionContent('''
我们可能会不时更新本隐私政策。重大变更会通过应用内通知告知您。
'''),

            const SizedBox(height: 32),

            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return Text(
      content.trim(),
      style: const TextStyle(
        fontSize: 16,
        height: 1.6,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(
                text: 'https://example.com/privacy-policy',
              ));
            },
            icon: const Icon(Icons.link),
            label: const Text('复制隐私政策链接'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse('mailto:support@example.com?subject=隐私政策咨询');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            icon: const Icon(Icons.email),
            label: const Text('通过邮件联系我们'),
          ),
        ),
      ],
    );
  }
}