import 'dart:typed_data';

/// IPv6工具类
/// 用于IPv6地址处理和CIDR计算
class IPv6Utils {
  /// 将IPv6字符串转换为16字节数组
  static Uint8List stringToBytes(String ipv6) {
    final bytes = Uint8List(16);

    // 处理IPv4映射的IPv6地址 (::ffff:192.0.2.128)
    if (ipv6.contains('.')) {
      final lastColon = ipv6.lastIndexOf(':');
      final ipv6Part = ipv6.substring(0, lastColon);
      final ipv4Part = ipv6.substring(lastColon + 1);

      // 解析IPv6部分
      final ipv6Bytes = stringToBytes(ipv6Part);
      bytes.setRange(0, 12, ipv6Bytes);

      // 解析IPv4部分
      final ipv4Parts = ipv4Part.split('.');
      for (int i = 0; i < 4; i++) {
        bytes[12 + i] = int.parse(ipv4Parts[i]);
      }
      return bytes;
    }

    // 查找双冒号(::)位置
    int doubleColonStart = ipv6.indexOf('::');

    if (doubleColonStart != -1) {
      // 处理压缩的IPv6地址
      final beforeColon = ipv6.substring(0, doubleColonStart);
      final afterColon = ipv6.substring(doubleColonStart + 2);

      final beforeParts = beforeColon.isEmpty ? [] : beforeColon.split(':');
      final afterParts = afterColon.isEmpty ? [] : afterColon.split(':');

      // 计算需要填充的零段数
      final totalParts = 8;
      final missingParts = totalParts - (beforeParts.length + afterParts.length);

      // 解析前半部分
      int byteIndex = 0;
      for (final part in beforeParts) {
        if (part.isEmpty) continue;
        final value = int.parse(part, radix: 16);
        bytes[byteIndex++] = (value >> 8) & 0xFF;
        bytes[byteIndex++] = value & 0xFF;
      }

      // 填充零
      for (int i = 0; i < missingParts; i++) {
        bytes[byteIndex++] = 0;
        bytes[byteIndex++] = 0;
      }

      // 解析后半部分
      for (final part in afterParts) {
        if (part.isEmpty) continue;
        final value = int.parse(part, radix: 16);
        bytes[byteIndex++] = (value >> 8) & 0xFF;
        bytes[byteIndex++] = value & 0xFF;
      }
    } else {
      // 处理未压缩的IPv6地址
      final parts = ipv6.split(':');
      int byteIndex = 0;

      for (final part in parts) {
        if (part.isEmpty) continue;
        final value = int.parse(part, radix: 16);
        bytes[byteIndex++] = (value >> 8) & 0xFF;
        bytes[byteIndex++] = value & 0xFF;
      }
    }

    return bytes;
  }

  /// 将16字节数组转换为IPv6字符串
  static String bytesToString(Uint8List bytes) {
    if (bytes.length != 16) throw ArgumentError('IPv6 address must be 16 bytes');

    // 检查是否是IPv4映射的IPv6地址
    if (_isIPv4MappedIPv6(bytes)) {
      final ipv4Bytes = bytes.sublist(12);
      final ipv4 = '${ipv4Bytes[0]}.${ipv4Bytes[1]}.${ipv4Bytes[2]}.${ipv4Bytes[3]}';
      return '::ffff:$ipv4';
    }

    // 将16字节转换为8个16位段
    final segments = <int>[];
    for (int i = 0; i < 16; i += 2) {
      segments.add((bytes[i] << 8) | bytes[i + 1]);
    }

    // 找到最长的连续零序列
    int maxZeroStart = -1;
    int maxZeroLength = 0;
    int currentZeroStart = -1;
    int currentZeroLength = 0;

    for (int i = 0; i < segments.length; i++) {
      if (segments[i] == 0) {
        if (currentZeroStart == -1) {
          currentZeroStart = i;
          currentZeroLength = 1;
        } else {
          currentZeroLength++;
        }
      } else {
        if (currentZeroLength > maxZeroLength) {
          maxZeroStart = currentZeroStart;
          maxZeroLength = currentZeroLength;
        }
        currentZeroStart = -1;
        currentZeroLength = 0;
      }
    }

    // 检查结尾的零序列
    if (currentZeroLength > maxZeroLength) {
      maxZeroStart = currentZeroStart;
      maxZeroLength = currentZeroLength;
    }

    // 如果只有一个零段，不压缩
    if (maxZeroLength < 2) {
      maxZeroStart = -1;
      maxZeroLength = 0;
    }

    // 构建结果字符串
    final result = <String>[];
    for (int i = 0; i < segments.length; i++) {
      if (i == maxZeroStart) {
        result.add('');
        // 跳过所有零段
        i += maxZeroLength - 1;
      } else if (i == maxZeroStart + maxZeroLength) {
        // 添加压缩后的内容
        result.add(segments[i].toRadixString(16));
      } else if (i < maxZeroStart || i > maxZeroStart + maxZeroLength) {
        result.add(segments[i].toRadixString(16));
      }
    }

    // 处理特殊情况
    String ipv6String;
    if (maxZeroStart == 0) {
      // 开头的零序列
      if (maxZeroLength == 8) {
        ipv6String = '::';
      } else {
        ipv6String = '::${result.skip(1).join(':')}';
      }
    } else if (maxZeroStart + maxZeroLength == 8) {
      // 结尾的零序列
      ipv6String = '${result.take(result.length - 1).join(':')}::';
    } else {
      // 中间的零序列
      ipv6String = result.join(':');
    }

    return ipv6String.toLowerCase();
  }

  /// 检查是否是IPv4映射的IPv6地址
  static bool _isIPv4MappedIPv6(Uint8List bytes) {
    if (bytes.length != 16) return false;

    // 检查前10个字节是否为0
    for (int i = 0; i < 10; i++) {
      if (bytes[i] != 0) return false;
    }

    // 检查第11、12个字节是否为0xFF
    if (bytes[10] != 0xFF || bytes[11] != 0xFF) return false;

    return true;
  }

  /// 将IPv6地址转换为大整数（用于比较）
  static BigInt ipv6ToInt(Uint8List bytes) {
    if (bytes.length != 16) throw ArgumentError('IPv6 address must be 16 bytes');

    BigInt result = BigInt.zero;
    for (int i = 0; i < 16; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  /// 从大整数转换为IPv6地址
  static Uint8List intToIPv6(BigInt value) {
    final bytes = Uint8List(16);
    for (int i = 15; i >= 0; i--) {
      bytes[i] = (value & BigInt.from(0xFF)).toInt();
      value = value >> 8;
    }
    return bytes;
  }

  /// 应用IPv6 CIDR掩码
  static Uint8List applyCIDR(Uint8List bytes, int cidr) {
    if (cidr == 0) {
      // 无掩码，返回原地址
      return Uint8List.fromList(bytes);
    }

    final result = Uint8List(16);
    final mask = generateCIDRMask(cidr);

    for (int i = 0; i < 16; i++) {
      result[i] = bytes[i] & mask[i];
    }

    return result;
  }

  /// 生成IPv6 CIDR掩码
  static Uint8List generateCIDRMask(int cidr) {
    if (cidr < 0 || cidr > 128) {
      throw ArgumentError('CIDR must be between 0 and 128');
    }

    final mask = Uint8List(16);
    final fullBytes = cidr ~/ 8;
    final remainingBits = cidr % 8;

    // 设置完整字节
    for (int i = 0; i < fullBytes; i++) {
      mask[i] = 0xFF;
    }

    // 设置剩余位
    if (remainingBits > 0) {
      mask[fullBytes] = 0xFF << (8 - remainingBits);
    }

    return mask;
  }

  /// 计算IPv6 CIDR范围的起始和结束地址
  static Map<String, Uint8List> calculateCIDRRange(String ipv6, int cidr) {
    final bytes = stringToBytes(ipv6);

    // 起始地址：应用掩码
    final start = applyCIDR(bytes, cidr);

    // 结束地址：起始地址 | (~掩码)
    final mask = generateCIDRMask(cidr);
    final invertedMask = Uint8List(16);

    for (int i = 0; i < 16; i++) {
      invertedMask[i] = ~mask[i] & 0xFF;
    }

    final end = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      end[i] = start[i] | invertedMask[i];
    }

    return {
      'start': start,
      'end': end,
    };
  }

  /// 比较两个IPv6地址
  static int compareIPv6(Uint8List a, Uint8List b) {
    for (int i = 0; i < 16; i++) {
      if (a[i] != b[i]) {
        return a[i].compareTo(b[i]);
      }
    }
    return 0;
  }

  /// 检查IPv6地址是否在范围内
  static bool isInRange(Uint8List address, Uint8List start, Uint8List end) {
    final addrInt = ipv6ToInt(address);
    final startInt = ipv6ToInt(start);
    final endInt = ipv6ToInt(end);

    return addrInt >= startInt && addrInt <= endInt;
  }
}