import 'package:flutter_test/flutter_test.dart';
import 'package:ech_wk_ios/core/ech_client.dart';
import 'package:ech_wk_ios/core/socks5_server.dart';
import 'package:ech_wk_ios/core/china_ip_database.dart';
import 'package:ech_wk_ios/core/proxy_server.dart';

void main() {
  group('ECH Core Tests', () {
    test('ECH Client initialization', () {
      final client = ECHClient(
        serverAddress: 'example.workers.dev',
        token: 'test-token',
      );

      expect(client.serverAddress, equals('example.workers.dev'));
      expect(client.token, equals('test-token'));
      expect(client.dnsServer, equals('dns.alidns.com/dns-query'));
    });

    test('China IP Database initialization', () async {
      final db = ChinaIPDatabase.instance;
      await db.initialize();

      final info = db.getInfo();
      expect(info['isInitialized'], isTrue);
    });

    test('IP range parsing', () {
      // 测试IP转换为整数
      final ip = '1.2.3.4';
      final parts = ip.split('.').map(int.parse).toList();
      var ipInt = 0;
      for (int i = 0; i < 4; i++) {
        ipInt = (ipInt << 8) | parts[i];
      }
      expect(ipInt, equals(0x01020304));
    });

    test('Routing Mode enum', () {
      final modes = RoutingMode.values;
      expect(modes.length, equals(3));
      expect(modes.contains(RoutingMode.global), isTrue);
      expect(modes.contains(RoutingMode.bypassCn), isTrue);
      expect(modes.contains(RoutingMode.none), isTrue);
    });
  });

  group('Proxy Server Tests', () {
    test('Proxy Server creation', () {
      final proxy = ECHProxyServer(
        serverAddress: 'test.workers.dev',
        port: 30001,
        token: 'test-token',
        routingMode: RoutingMode.global,
      );

      expect(proxy.serverAddress, equals('test.workers.dev'));
      expect(proxy.port, equals(30001));
    });

    test('Proxy Server status', () async {
      final proxy = ECHProxyServer(
        serverAddress: 'test.workers.dev',
        port: 30002,
      );

      final status = proxy.getStatus();
      expect(status['isRunning'], isFalse);
      expect(status['serverAddress'], equals('test.workers.dev'));
    });
  });
}