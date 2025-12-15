import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'ipv6_utils.dart';

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

  /// 初始化IP数据库
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 从assets加载IPv4数据
      await _loadIPv4Data();

      // 从assets加载IPv6数据
      await _loadIPv6Data();

      _isInitialized = true;
      print('China IP database initialized');
      print('Loaded ${_ipv4Ranges.length} IPv4 ranges');
      print('Loaded ${_ipv6Ranges.length} IPv6 ranges');
    } catch (e) {
      print('Failed to initialize China IP database: $e');
      // 加载默认的测试数据
      await _loadDefaultData();
    }
  }

  /// 从文件加载IPv4数据
  Future<void> _loadIPv4Data() async {
    try {
      // 尝试从assets加载
      final data = await rootBundle.loadString('assets/config/chn_ip.txt');
      _parseIPv4Data(data);
    } catch (e) {
      // 如果assets中没有，尝试从网络下载
      await _downloadAndLoadIPv4Data();
    }
  }

  /// 从文件加载IPv6数据
  Future<void> _loadIPv6Data() async {
    try {
      // 尝试从assets加载
      final data = await rootBundle.loadString('assets/config/chn_ip_v6.txt');
      _parseIPv6Data(data);
    } catch (e) {
      // 如果assets中没有，尝试从网络下载
      await _downloadAndLoadIPv6Data();
    }
  }

  /// 从网络下载并加载IPv4数据
  Future<void> _downloadAndLoadIPv4Data() async {
    const url = 'https://raw.githubusercontent.com/mayaxcn/china-ip-list/refs/heads/master/chn_ip.txt';

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final data = await response.transform(utf8.decoder).join();
      _parseIPv4Data(data);

      // 保存到本地缓存
      await _saveToCache('chn_ip.txt', data);
    } catch (e) {
      print('Failed to download IPv4 data: $e');
      rethrow;
    }
  }

  /// 从网络下载并加载IPv6数据
  Future<void> _downloadAndLoadIPv6Data() async {
    const url = 'https://raw.githubusercontent.com/mayaxcn/china-ip-list/refs/heads/master/chn_ip_v6.txt';

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final data = await response.transform(utf8.decoder).join();
      _parseIPv6Data(data);

      // 保存到本地缓存
      await _saveToCache('chn_ip_v6.txt', data);
    } catch (e) {
      print('Failed to download IPv6 data: $e');
      rethrow;
    }
  }

  /// 解析IPv4数据
  void _parseIPv4Data(String data) {
    final lines = data.split('\n');
    final ranges = <IpRange>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.contains('/')) {
        final parts = trimmed.split('/');
        if (parts.length == 2) {
          final ip = parts[0];
          final cidr = int.parse(parts[1]);

          final range = _parseCIDRToRange(ip, cidr);
          if (range != null) {
            ranges.add(range);
          }
        }
      }
    }

    // 按起始IP排序，用于二分查找
    ranges.sort((a, b) => a.start.compareTo(b.start));
    _ipv4Ranges = ranges;
  }

  /// 解析IPv6数据
  void _parseIPv6Data(String data) {
    final lines = data.split('\n');
    final ranges = <IpRangeV6>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (trimmed.contains('/')) {
        final parts = trimmed.split('/');
        if (parts.length == 2) {
          final ip = parts[0];
          final cidr = int.parse(parts[1]);

          final range = _parseIPv6CIDRToRange(ip, cidr);
          if (range != null) {
            ranges.add(range);
          }
        }
      }
    }

    _ipv6Ranges = ranges;
  }

  /// 解析CIDR到IP范围（IPv4）
  IpRange? _parseCIDRToRange(String ip, int cidr) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;

    try {
      int ipInt = 0;
      for (int i = 0; i < 4; i++) {
        ipInt = (ipInt << 8) | int.parse(parts[i]);
      }

      final mask = (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
      final start = ipInt & mask;
      final end = start | (~mask & 0xFFFFFFFF);

      return IpRange(start, end);
    } catch (e) {
      return null;
    }
  }

  /// 解析CIDR到IP范围（IPv6）
  IpRangeV6? _parseIPv6CIDRToRange(String ip, int cidr) {
    try {
      return IpRangeV6.fromCIDR(ip, cidr);
    } catch (e) {
      print('Failed to parse IPv6 CIDR: $ip/$cidr - $e');
      return null;
    }
  }

  /// 保存到缓存
  Future<void> _saveToCache(String filename, String data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(data);
    } catch (e) {
      print('Failed to save cache: $e');
    }
  }

  /// 加载默认的测试数据
  Future<void> _loadDefaultData() async {
    // 添加一些常见的中国IP段作为默认数据
    _ipv4Ranges.addAll([
      IpRange(_ipToInt('1.0.0.0'), _ipToInt('1.255.255.255')),
      IpRange(_ipToInt('58.0.0.0'), _ipToInt('58.255.255.255')),
      IpRange(_ipToInt('117.0.0.0'), _ipToInt('117.255.255.255')),
      IpRange(_ipToInt('121.0.0.0'), _ipToInt('121.255.255.255')),
      IpRange(_ipToInt('123.0.0.0'), _ipToInt('123.255.255.255')),
    ]);

    _isInitialized = true;
    print('Loaded default test data');
  }

  /// 将IP地址转换为整数
  int _ipToInt(String ip) {
    final parts = ip.split('.');
    int result = 0;
    for (int i = 0; i < 4; i++) {
      result = (result << 8) | int.parse(parts[i]);
    }
    return result;
  }

  /// 判断IP是否在中国（IPv4）
  bool isChinaIPv4(String ip) {
    if (!_isInitialized) return false;

    try {
      final ipInt = _ipToInt(ip);

      // 使用二分查找
      int low = 0;
      int high = _ipv4Ranges.length - 1;

      while (low <= high) {
        final mid = (low + high) ~/ 2;
        final range = _ipv4Ranges[mid];

        if (ipInt >= range.start && ipInt <= range.end) {
          return true;
        } else if (ipInt < range.start) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 判断IP是否在中国（IPv6）
  bool isChinaIPv6(String ip) {
    if (!_isInitialized) return false;

    try {
      for (final range in _ipv6Ranges) {
        if (range.contains(ip)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // IP查询缓存
  final Map<String, bool> _ipCache = {};
  final Map<String, bool> _hostCache = {};
  static const Duration _cacheTimeout = Duration(minutes: 30);
  final Map<String, DateTime> _cacheTimestamps = {};

  /// 统一的判断方法（带缓存）
  Future<bool> isChinaIP(String host) async {
    // 检查缓存
    if (_hostCache.containsKey(host)) {
      final timestamp = _cacheTimestamps[host];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheTimeout) {
        return _hostCache[host]!;
      }
    }

    try {
      // 如果host本身就是IP地址
      if (_isIPAddress(host)) {
        final result = _isIPChina(host);
        _hostCache[host] = result;
        _cacheTimestamps[host] = DateTime.now();
        return result;
      }

      // 查找域名的所有IP地址
      final addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.any,
      );

      bool foundChinaIP = false;
      bool foundForeignIP = false;

      for (final addr in addresses) {
        final ipStr = addr.address;

        // 检查IP缓存
        bool isChina;
        if (_ipCache.containsKey(ipStr)) {
          isChina = _ipCache[ipStr]!;
        } else {
          if (addr.type == InternetAddressType.IPv4) {
            isChina = isChinaIPv4(ipStr);
          } else if (addr.type == InternetAddressType.IPv6) {
            isChina = isChinaIPv6(ipStr);
          } else {
            continue;
          }
          _ipCache[ipStr] = isChina;
        }

        if (isChina) {
          foundChinaIP = true;
        } else {
          foundForeignIP = true;
        }
      }

      // 如果同时有中国和海外IP，优先判断为中国
      // 这种情况通常是CDN服务
      final result = foundChinaIP || !foundForeignIP;

      // 缓存结果
      _hostCache[host] = result;
      _cacheTimestamps[host] = DateTime.now();

      return result;
    } catch (e) {
      print('Error checking IP for $host: $e');

      // 如果查询失败，尝试从域名判断
      if (host.endsWith('.cn') ||
          host.endsWith('.com.cn') ||
          host.endsWith('.net.cn') ||
          host.endsWith('.org.cn') ||
          host.endsWith('.gov.cn') ||
          host.endsWith('.edu.cn')) {
        return true;
      }

      return false;
    }
  }

  /// 判断字符串是否是IP地址
  bool _isIPAddress(String str) {
    // IPv4正则
    final ipv4Pattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (ipv4Pattern.hasMatch(str)) {
      final parts = str.split('.');
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          return false;
        }
      }
      return true;
    }

    // IPv6正则（简化版）
    final ipv6Pattern = RegExp(r'^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$');
    if (ipv6Pattern.hasMatch(str)) {
      return true;
    }

    // 压缩的IPv6
    if (str.contains('::')) {
      final parts = str.split(':');
      if (parts.length <= 8) {
        return true;
      }
    }

    return false;
  }

  /// 直接判断IP是否在中国（不需要DNS查询）
  bool _isIPChina(String ip) {
    if (_isIPAddress(ip)) {
      if (ip.contains('.')) {
        return isChinaIPv4(ip);
      } else {
        return isChinaIPv6(ip);
      }
    }
    return false;
  }

  /// 清除缓存
  void clearCache() {
    _ipCache.clear();
    _hostCache.clear();
    _cacheTimestamps.clear();
  }

  /// 清除过期缓存
  void _clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _cacheTimeout) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _cacheTimestamps.remove(key);
      _hostCache.remove(key);
    }
  }

  /// 获取数据库信息
  Map<String, dynamic> getInfo() {
    // 清除过期缓存
    _clearExpiredCache();

    return {
      'isInitialized': _isInitialized,
      'ipv4RangeCount': _ipv4Ranges.length,
      'ipv6RangeCount': _ipv6Ranges.length,
      'ipCacheSize': _ipCache.length,
      'hostCacheSize': _hostCache.length,
      'cacheTimeoutMinutes': _cacheTimeout.inMinutes,
    };
  }
}