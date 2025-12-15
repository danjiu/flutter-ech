import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'ipv6_utils.dart';

/// IP范围数据类（IPv4）
class IpRange {
  final int start;
  final int end;

  IpRange(this.start, this.end);
}

/// IP范围数据类（IPv6）
class IpRangeV6 {
  final Uint8List start;
  final Uint8List end;

  IpRangeV6(this.start, this.end);

  /// 创建IPv6范围
  factory IpRangeV6.fromCIDR(String ipv6, int cidr) {
    final range = IPv6Utils.calculateCIDRRange(ipv6, cidr);
    return IpRangeV6(
      range['start'] as Uint8List,
      range['end'] as Uint8List,
    );
  }

  /// 检查IP是否在范围内
  bool contains(String ip) {
    final ipBytes = IPv6Utils.stringToBytes(ip);
    return IPv6Utils.isInRange(ipBytes, start, end);
  }
}

/// 中国IP数据库管理
class ChinaIPDatabase {
  static ChinaIPDatabase? _instance;
  static ChinaIPDatabase get instance {
    _instance ??= ChinaIPDatabase._();
    return _instance!;
  }

  ChinaIPDatabase._();

  // IPv4 IP段列表（使用二分查找优化）
  List<IpRange> _ipv4Ranges = [];

  // IPv6 IP段列表
  List<IpRangeV6> _ipv6Ranges = [];

  /// 是否已初始化
  bool _isInitialized = false;

  /// 获取初始化状态
  bool get isInitialized => _isInitialized;

  /// 初始化IP数据库
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 从assets加载IPv4数据
      await _loadIPv4Data();

      // 从assets加载IPv6数据
      await _loadIPv6Data();

      _isInitialized = true;
    } catch (e) {
      print('初始化中国IP数据库失败: $e');
    }
  }

  /// 加载IPv4数据
  Future<void> _loadIPv4Data() async {
    try {
      final data = await rootBundle.loadString('assets/data/china_ipv4.txt');
      final lines = data.split('\n');

      for (final line in lines) {
        if (line.isEmpty) continue;

        final parts = line.split('-');
        if (parts.length != 2) continue;

        final start = int.parse(parts[0].trim());
        final end = int.parse(parts[1].trim());

        _ipv4Ranges.add(IpRange(start, end));
      }
    } catch (e) {
      // 如果assets文件不存在，加载默认数据
      _loadDefaultIPv4Data();
    }
  }

  /// 加载默认IPv4数据
  void _loadDefaultIPv4Data() {
    // 这里添加一些默认的中国IP段
    final defaultRanges = [
      IpRange(167772160, 184549375),      // 10.0.0.0/8
      IpRange(2886729728, 2887778303),    // 172.16.0.0/12
      IpRange(3232235520, 3232301055),    // 192.168.0.0/16
      // 添加更多中国IP段...
    ];

    _ipv4Ranges.addAll(defaultRanges);
  }

  /// 加载IPv6数据
  Future<void> _loadIPv6Data() async {
    try {
      final data = await rootBundle.loadString('assets/data/china_ipv6.txt');
      final lines = data.split('\n');

      for (final line in lines) {
        if (line.isEmpty) continue;

        final parts = line.split(' ');
        if (parts.length != 2) continue;

        final range = IpRangeV6.fromCIDR(parts[0], int.parse(parts[1]));
        _ipv6Ranges.add(range);
      }
    } catch (e) {
      // 如果assets文件不存在，加载默认数据
      _loadDefaultIPv6Data();
    }
  }

  /// 加载默认IPv6数据
  void _loadDefaultIPv6Data() {
    // 这里添加一些默认的中国IPv6段
    final defaultRanges = [
      IpRangeV6.fromCIDR('2001:db8::', 32),
      // 添加更多中国IPv6段...
    ];

    _ipv6Ranges.addAll(defaultRanges);
  }

  /// 检查IPv4地址是否在中国
  bool isChineseIPv4(String ip) {
    if (!_isInitialized) return false;

    final ipInt = _ipToInt(ip);
    if (ipInt == null) return false;

    // 使用二分查找
    int left = 0;
    int right = _ipv4Ranges.length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final range = _ipv4Ranges[mid];

      if (ipInt >= range.start && ipInt <= range.end) {
        return true;
      } else if (ipInt < range.start) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return false;
  }

  /// 检查IPv6地址是否在中国
  bool isChineseIPv6(String ip) {
    if (!_isInitialized) return false;

    for (final range in _ipv6Ranges) {
      if (range.contains(ip)) {
        return true;
      }
    }

    return false;
  }

  /// 检查IP地址是否在中国（支持IPv4和IPv6）
  bool isChineseIP(String ip) {
    if (ip.contains(':')) {
      return isChineseIPv6(ip);
    } else {
      return isChineseIPv4(ip);
    }
  }

  /// IPv4地址转换为整数
  int? _ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;

    try {
      int result = 0;
      for (int i = 0; i < 4; i++) {
        final part = int.parse(parts[i]);
        if (part < 0 || part > 255) return null;
        result = (result << 8) | part;
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  /// 保存数据到本地缓存
  Future<void> saveToLocalCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/china_ip_cache.json');

      final cache = {
        'ipv4': _ipv4Ranges.map((r) => [r.start, r.end]).toList(),
        'ipv6': _ipv6Ranges.map((r) => [
          r.start.map((b) => b).toList(),
          r.end.map((b) => b).toList()
        ]).toList(),
      };

      await file.writeAsString(json.encode(cache));
    } catch (e) {
      print('保存缓存失败: $e');
    }
  }

  /// 从本地缓存加载数据
  Future<void> loadFromLocalCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/china_ip_cache.json');

      if (!await file.exists()) return;

      final content = await file.readAsString();
      final cache = json.decode(content) as Map<String, dynamic>;

      _ipv4Ranges = (cache['ipv4'] as List)
          .map((r) => IpRange(r[0] as int, r[1] as int))
          .toList();

      _ipv6Ranges = (cache['ipv6'] as List)
          .map((r) => IpRangeV6(
                Uint8List.fromList(r[0] as List<int>),
                Uint8List.fromList(r[1] as List<int>),
              ))
          .toList();

      _isInitialized = true;
    } catch (e) {
      print('加载缓存失败: $e');
    }
  }
}