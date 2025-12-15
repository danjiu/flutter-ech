import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/ipv6_utils.dart';

void main() {
  group('IPv6 Utils Tests', () {
    test('stringToBytes - 正常IPv6地址', () {
      final result = IPv6Utils.stringToBytes('2001:0db8:85a3:0000:0000:8a2e:0370:7334');
      expect(result.length, 16);
      expect(result[0], 0x20);
      expect(result[1], 0x01);
      expect(result[2], 0x0d);
      expect(result[3], 0xb8);
    });

    test('stringToBytes - 压缩IPv6地址', () {
      final result = IPv6Utils.stringToBytes('2001:db8::8a2e:370:7334');
      expect(result.length, 16);
      expect(result[0], 0x20);
      expect(result[1], 0x01);
      expect(result[2], 0x0d);
      expect(result[3], 0xb8);
      // 中间的零应该被填充
      expect(result.sublist(4, 16), everyElement(0));
    });

    test('bytesToString - 转换为字符串', () {
      final bytes = Uint8List.fromList([
        0x20, 0x01, 0x0d, 0xb8, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34
      ]);
      final result = IPv6Utils.bytesToString(bytes);
      expect(result, '2001:db8::8a2e:370:7334');
    });

    test('bytesToString - 全零地址', () {
      final bytes = Uint8List(16);
      final result = IPv6Utils.bytesToString(bytes);
      expect(result, '::');
    });

    test('bytesToString - IPv4映射地址', () {
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0xff, 0xff, 192, 168, 1, 1
      ]);
      final result = IPv6Utils.bytesToString(bytes);
      expect(result, '::ffff:192.168.1.1');
    });

    test('calculateCIDRRange - 基本CIDR计算', () {
      final range = IPv6Utils.calculateCIDRRange('2001:db8::', 32);
      expect(range['start'], isA<Uint8List>());
      expect(range['end'], isA<Uint8List>());

      // 验证起始地址
      final start = range['start'] as Uint8List;
      expect(start[0], 0x20);
      expect(start[1], 0x01);
      expect(start[2], 0x0d);
      expect(start[3], 0xb8);
    });

    test('isInRange - 范围检查', () {
      final range = IPv6Utils.calculateCIDRRange('2001:db8::', 32);
      final start = range['start'] as Uint8List;
      final end = range['end'] as Uint8List;

      // 测试范围内的IP
      final testIP1 = IPv6Utils.stringToBytes('2001:db8::1');
      expect(IPv6Utils.isInRange(testIP1, start, end), true);

      // 测试范围外的IP
      final testIP2 = IPv6Utils.stringToBytes('2001:db9::1');
      expect(IPv6Utils.isInRange(testIP2, start, end), false);
    });
  });
}