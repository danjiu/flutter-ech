import 'dart:typed_data';

/// 简化的DNS解析器
/// 用于解析DoH响应并提取HTTPS记录
class DNSParser {
  /// 解析DNS查询响应
  static List<HTTPSRecord> parseDNSResponse(Uint8List data) {
    final records = <HTTPSRecord>[];
    int offset = 12; // 跳过DNS头部

    // 跳过查询部分
    offset = _skipQuestions(data, offset);

    // 解析回答部分
    while (offset < data.length) {
      final record = _parseRecord(data, offset);
      if (record != null && record.type == 65) { // HTTPS记录
        final httpsRecord = parseHTTPSRecord(record);
        if (httpsRecord != null) {
          records.add(httpsRecord);
        }
      }

      offset = record?.nextOffset ?? data.length;
    }

    return records;
  }

  /// 跳过查询部分
  static int _skipQuestions(Uint8List data, int offset) {
    // 跳过查询名称
    while (offset < data.length) {
      if (data[offset] == 0) {
        offset += 1;
        break;
      }
      final len = data[offset++];
      offset += len;
    }

    return offset + 4; // QTYPE + QCLASS
  }

  /// 解析单个记录
  static Record? _parseRecord(Uint8List data, int offset) {
    if (offset + 10 >= data.length) return null;

    // 跳过名称（简化处理）
    while (offset < data.length && data[offset] != 0) {
      final len = data[offset++];
      if (len == 0) break;
      offset += len;
    }
    if (offset >= data.length) return null;
    offset++; // 跳过0长度标签

    // 读取类型
    final type = (data[offset] << 8) | data[offset + 1];
    offset += 8; // Type + Class + TTL

    // 读取数据长度
    if (offset + 2 >= data.length) return null;
    final dataLen = (data[offset] << 8) | data[offset + 1];
    offset += 2;

    // 读取数据
    final recordData = Uint8List.fromList(data.sublist(offset, offset + dataLen));

    return Record(
      type: type,
      data: recordData,
      nextOffset: offset + dataLen,
    );
  }

  /// 解析HTTPS记录中的SVCB/HTTPS数据
  static HTTPSRecord? parseHTTPSRecord(Record record) {
    if (record.data.length < 4) return null;

    final data = record.data;
    int offset = 0;

    // SvcPriority (2 bytes)
    if (offset + 2 > data.length) return null;
    final priority = (data[offset] << 8) | data[offset + 1];
    offset += 2;

    // TargetName (可变长度)
    // 检查是否是别名模式（priority != 0）
    String? targetName;
    final svcParams = <String, Uint8List>{};
    Uint8List? echConfig;

    if (priority != 0) {
      // Service mode - 解析TargetName
      if (offset >= data.length) return null;

      // TargetName是域名，格式与DNS QNAME相同
      targetName = _parseDNSName(data, offset);
      if (targetName == null) return null;

      // 计算TargetName占用的字节数
      int nameLen = 0;
      int tempOffset = offset;
      while (tempOffset < data.length) {
        final len = data[tempOffset++];
        if (len == 0) break;
        nameLen += 1 + len;
        tempOffset += len;
      }
      offset += nameLen + 1;
    }

    // 解析SvcParam键值对列表
    while (offset < data.length) {
      if (offset + 4 > data.length) break;

      // SvcParamKey (2 bytes)
      final paramKey = (data[offset] << 8) | data[offset + 1];
      offset += 2;

      // SvcParamValueLength (2 bytes)
      final valueLength = (data[offset] << 8) | data[offset + 1];
      offset += 2;

      if (offset + valueLength > data.length) break;

      // SvcParamValue
      final valueData = Uint8List.fromList(data.sublist(offset, offset + valueLength));
      offset += valueLength;

      // 解析已知的参数键
      final paramName = _getSvcParamKeyName(paramKey);
      svcParams[paramName] = valueData;

      // 如果是ECH参数，单独保存
      if (paramKey == 5 || paramName == 'ech') {
        echConfig = valueData;
      }
    }

    return HTTPSRecord(
      priority: priority,
      targetName: targetName,
      svcParams: svcParams,
      echConfig: echConfig,
    );
  }

  /// 解析DNS名称
  static String? _parseDNSName(Uint8List data, int offset) {
    final labels = <String>[];
    int originalOffset = offset;
    bool jumped = false;

    while (offset < data.length) {
      final len = data[offset];

      if (len == 0) {
        offset++;
        break;
      } else if ((len & 0xC0) == 0xC0) {
        // DNS压缩指针
        if (offset + 1 >= data.length) return null;

        if (!jumped) {
          originalOffset = offset + 2;
          jumped = true;
        }

        final pointer = ((len & 0x3F) << 8) | data[offset + 1];
        offset = pointer;
      } else {
        offset++;
        if (offset + len > data.length) return null;

        final label = String.fromCharCodes(data, offset, offset + len);
        labels.add(label);
        offset += len;
      }
    }

    return labels.join('.');
  }

  /// 获取SvcParamKey的名称
  static String _getSvcParamKeyName(int key) {
    switch (key) {
      case 0: return 'mandatory';
      case 1: return 'alpn';
      case 2: return 'no-default-alpn';
      case 3: return 'port';
      case 4: return 'ipv4hint';
      case 5: return 'ech';
      case 6: return 'ipv6hint';
      case 7: return 'dohpath';
      case 8: return 'ohttp';
      default: return 'key$key';
    }
  }

  /// 解析ALPN协议列表
  static List<String> parseALPNList(Uint8List data) {
    if (data.isEmpty) return [];

    final alpnList = <String>[];
    int offset = 0;

    while (offset < data.length) {
      final length = data[offset++];
      if (offset + length > data.length) break;

      final alpn = String.fromCharCodes(data, offset, offset + length);
      alpnList.add(alpn);
      offset += length;
    }

    return alpnList;
  }

  /// 解析端口
  static int parsePort(Uint8List data) {
    if (data.length < 2) return 443; // 默认HTTPS端口
    return (data[0] << 8) | data[1];
  }

  /// 解析IPv4地址
  static String parseIPv4(Uint8List data) {
    if (data.length != 4) return '';
    return '${data[0]}.${data[1]}.${data[2]}.${data[3]}';
  }

  /// 解析IPv6地址
  static String parseIPv6(Uint8List data) {
    if (data.length != 16) return '';

    final parts = <String>[];
    for (int i = 0; i < 16; i += 2) {
      parts.add('${data[i].toRadixString(16).padLeft(2, '0')}');
    }

    return parts.join(':');
  }
}

/// DNS记录
class Record {
  final int type;
  final Uint8List data;
  final int nextOffset;

  Record({
    required this.type,
    required this.data,
    required this.nextOffset,
  });
}

/// HTTPS/SVCB记录
class HTTPSRecord {
  final int priority;
  final String? targetName;
  final Map<String, Uint8List> svcParams;
  final Uint8List? echConfig;

  HTTPSRecord({
    required this.priority,
    this.targetName,
    required this.svcParams,
    this.echConfig,
  });

  /// 获取ALPN协议列表（如果有）
  List<String>? get alpn {
    final alpnData = svcParams['alpn'];
    if (alpnData == null) return null;
    return DNSParser.parseALPNList(alpnData);
  }

  /// 获取端口（如果配置了强制HTTPS）
  int? get forcedPort {
    final portData = svcParams['port'];
    if (portData == null) return null;
    return DNSParser.parsePort(portData);
  }

  /// 获取IPv4地址（如果配置了）
  String? get ipv4Hint {
    final ipv4Data = svcParams['ipv4hint'];
    if (ipv4Data == null) return null;
    return DNSParser.parseIPv4(ipv4Data);
  }

  /// 获取IPv6地址（如果配置了）
  String? get ipv6Hint {
    final ipv6Data = svcParams['ipv6hint'];
    if (ipv6Data == null) return null;
    return DNSParser.parseIPv6(ipv6Data);
  }

  /// 获取ECH配置列表
  List<Uint8List>? get echConfigList {
    final echData = svcParams['ech'];
    if (echData == null) return null;

    // ECH配置列表格式：
    // 2字节长度 + ECH配置
    final configs = <Uint8List>[];
    int offset = 0;

    while (offset < echData.length) {
      if (offset + 2 > echData.length) break;
      final configLen = (echData[offset] << 8) | echData[offset + 1];
      offset += 2;

      if (offset + configLen > echData.length) break;
      configs.add(Uint8List.fromList(echData.sublist(offset, offset + configLen)));
      offset += configLen;
    }

    return configs;
  }
}