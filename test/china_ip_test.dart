import 'package:flutter_test/flutter_test.dart';
import '../lib/core/china_ip_database.dart';

void main() {
  group('China IP Database Tests', () {
    late ChinaIPDatabase db;

    setUpAll(() async {
      db = ChinaIPDatabase.instance;
      await db.initialize();
    });

    test('isChinaIPv4 - 测试中国IP', () {
      expect(db.isChinaIPv4('1.2.3.4'), true); // 中国联通
      expect(db.isChinaIPv4('58.250.0.1'), true); // 中国电信
      expect(db.isChinaIPv4('123.125.114.144'), true); // 中国移动
    });

    test('isChinaIPv4 - 测试海外IP', () {
      expect(db.isChinaIPv4('8.8.8.8'), false); // Google DNS
      expect(db.isChinaIPv4('1.1.1.1'), false); // Cloudflare DNS
    });

    test('isChinaIPv6 - 测试中国IPv6', () {
      expect(db.isChinaIPv6('2408:8000::1'), true); // 中国联通
      expect(db.isChinaIPv6('240e:0000::1'), true); // 中国电信
      expect(db.isChinaIPv6('2409:8000::1'), true); // 中国移动
    });

    test('isChinaIPv6 - 测试海外IPv6', () {
      expect(db.isChinaIPv6('2001:4860:4860::8888'), false); // Google IPv6
      expect(db.isChinaIPv6('2606:4700:4700::1111'), false); // Cloudflare IPv6
    });

    test('isChinaIP - 域名测试', () async {
      expect(await db.isChinaIP('baidu.com'), true);
      expect(await db.isChinaIP('qq.com'), true);
      expect(await db.isChinaIP('google.com'), false);
      expect(await db.isChinaIP('facebook.com'), false);
    });

    test('isChinaIP - 直接IP测试', () async {
      expect(await db.isChinaIP('114.114.114.114'), true); // 114 DNS
      expect(await db.isChinaIP('223.5.5.5'), true); // 阿里DNS
      expect(await db.isChinaIP('8.8.8.8'), false);
    });

    test('缓存功能', () async {
      // 第一次查询
      final start = DateTime.now();
      final result1 = await db.isChinaIP('baidu.com');
      final duration1 = DateTime.now().difference(start);

      // 第二次查询（应该从缓存获取）
      final start2 = DateTime.now();
      final result2 = await db.isChinaIP('baidu.com');
      final duration2 = DateTime.now().difference(start2);

      expect(result1, result2);
      expect(duration2.inMilliseconds, lessThan(duration1.inMilliseconds));
    });

    test('获取数据库信息', () {
      final info = db.getInfo();
      expect(info['isInitialized'], true);
      expect(info['ipv4RangeCount'], greaterThan(0));
      expect(info['ipv6RangeCount'], greaterThan(0));
      expect(info['ipCacheSize'], greaterThanOrEqualTo(0));
      expect(info['hostCacheSize'], greaterThanOrEqualTo(0));
    });
  });
}