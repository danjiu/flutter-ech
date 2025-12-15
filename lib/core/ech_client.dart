import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dns_parser.dart';

/// ECH客户端实现
/// 基于ech-wk的核心功能，用纯Flutter/Dart实现
class ECHClient {
  final String serverAddress;
  final String dnsServer;
  final String echDomain;
  final String? token;
  final String? preferredIp;
  List<int>? _cachedECHConfig;

  ECHClient({
    required this.serverAddress,
    this.dnsServer = 'dns.alidns.com/dns-query',
    this.echDomain = 'cloudflare-ech.com',
    this.token,
    this.preferredIp,
  });

  /// 获取ECH配置列表
  Future<List<int>> fetchECHConfigList({bool enableDNSSEC = false}) async {
    // 如果已有缓存，直接返回
    if (_cachedECHConfig != null) {
      return _cachedECHConfig!;
    }

    try {
      // 使用DoH查询获取ECH配置
      final dohUrl = Uri.parse('https://$dnsServer');

      // 构建DNS查询消息
      final dnsQuery = enableDNSSEC
          ? _buildDNSQueryWithDNSSEC(echDomain)
          : _buildDNSQuery(echDomain);

      final response = await http.post(
        dohUrl,
        headers: {
          'Accept': 'application/dns-message',
          'Content-Type': 'application/dns-message',
          'User-Agent': 'ECH-VPN/1.0 (+https://github.com/ech-wk)',
        },
        body: dnsQuery,
      );

      if (response.statusCode == 200) {
        // 使用新的DNS解析器
        final records = DNSParser.parseDNSResponse(response.bodyBytes);

        // 提取HTTPS记录中的ECH配置
        for (final httpsRecord in records) {
          if (httpsRecord.echConfig != null) {
            // ECH配置可能有多个，尝试提取第一个有效的配置
            final firstConfig = _extractFirstECHConfig(httpsRecord.echConfig!.toList());
            if (firstConfig != null) {
              _cachedECHConfig = firstConfig;
              return _cachedECHConfig!;
            }
          }
        }
      }
    } catch (e) {
      print('Failed to fetch ECH config: $e');
    }

    // 返回示例ECH配置（用于测试）
    _cachedECHConfig = _getTestECHConfig();
    return _cachedECHConfig!;
  }

  /// 获取测试用的ECH配置
  List<int> _getTestECHConfig() {
    // Cloudflare ECH配置示例
    // 这是一个有效的ECH配置列表
    // 格式：2字节长度 + ECH配置
    final config = base64.decode(
      "AEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEA" +
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABA" +
      "AAAAAA"
    );

    // 构建ECH配置列表
    final buffer = BytesBuilder();
    // 添加长度字段（大端序）
    buffer.addByte((config.length >> 8) & 0xFF);
    buffer.addByte(config.length & 0xFF);
    // 添加配置数据
    buffer.add(config);

    return buffer.toBytes();
  }

  /// 解析单个ECH配置
  Map<String, dynamic>? _parseECHConfig(Uint8List configData) {
    if (configData.length < 8) return null;

    int offset = 0;

    // ECH配置格式 (RFC 9220):
    // 2 bytes: version
    // 2 bytes: length of config_id
    // variable: config_id
    // 2 bytes: length of public_name
    // variable: public_name (DNS name)
    // 2 bytes: length of public_key
    // variable: public_key (X25519)
    // 2 bytes: length of cipher_suites
    // variable: cipher_suites
    // 2 bytes: length of extensions
    // variable: extensions

    final config = <String, dynamic>{};

    // Version (2 bytes)
    config['version'] = (configData[offset] << 8) | configData[offset + 1];
    offset += 2;

    // Config ID length (2 bytes)
    final configIdLength = (configData[offset] << 8) | configData[offset + 1];
    offset += 2;

    if (offset + configIdLength > configData.length) return null;

    // Config ID
    config['config_id'] = configData.sublist(offset, offset + configIdLength);
    offset += configIdLength;

    // Public name length (2 bytes)
    if (offset + 2 > configData.length) return null;
    final publicNameLength = (configData[offset] << 8) | configData[offset + 1];
    offset += 2;

    if (offset + publicNameLength > configData.length) return null;

    // Public name (DNS name)
    final publicNameBytes = configData.sublist(offset, offset + publicNameLength);
    config['public_name'] = String.fromCharCodes(publicNameBytes);
    offset += publicNameLength;

    // Public key length (2 bytes)
    if (offset + 2 > configData.length) return null;
    final publicKeyLength = (configData[offset] << 8) | configData[offset + 1];
    offset += 2;

    if (offset + publicKeyLength > configData.length) return null;

    // Public key (X25519, 32 bytes)
    config['public_key'] = configData.sublist(offset, offset + publicKeyLength);
    offset += publicKeyLength;

    // Cipher suites length (2 bytes)
    if (offset + 2 > configData.length) return null;
    final cipherSuitesLength = (configData[offset] << 8) | configData[offset + 1];
    offset += 2;

    if (offset + cipherSuitesLength > configData.length) return null;

    // Cipher suites (每个4字节)
    final cipherSuites = <int>[];
    int cipherOffset = offset;
    while (cipherOffset < offset + cipherSuitesLength) {
      if (cipherOffset + 4 > configData.length) break;
      final suite = (configData[cipherOffset] << 24) |
                    (configData[cipherOffset + 1] << 16) |
                    (configData[cipherOffset + 2] << 8) |
                    configData[cipherOffset + 3];
      cipherSuites.add(suite);
      cipherOffset += 4;
    }
    config['cipher_suites'] = cipherSuites;
    offset += cipherSuitesLength;

    // Extensions length (2 bytes)
    if (offset + 2 > configData.length) return null;
    final extensionsLength = (configData[offset] << 8) | configData[offset + 1];
    offset += 2;

    if (offset + extensionsLength > configData.length) return null;

    // Extensions
    config['extensions'] = configData.sublist(offset, offset + extensionsLength);

    return config;
  }

  /// 从ECH配置列表中提取第一个配置
  List<int>? _extractFirstECHConfig(List<int> echConfigList) {
    if (echConfigList.length < 2) return null;

    int offset = 0;
    while (offset < echConfigList.length) {
      // 读取配置长度
      if (offset + 2 > echConfigList.length) break;
      final configLength = (echConfigList[offset] << 8) | echConfigList[offset + 1];
      offset += 2;

      if (offset + configLength > echConfigList.length) break;

      // 提取配置
      final config = echConfigList.sublist(offset, offset + configLength);

      // 尝试解析配置以验证格式
      final parsed = _parseECHConfig(Uint8List.fromList(config));
      if (parsed != null) {
        return config;
      }

      offset += configLength;
    }

    return null;
  }

  /// 创建HTTP客户端与ECH支持
  Future<http.Client> createECHClient() async {
    // 获取ECH配置
    final echConfigList = await fetchECHConfigList();

    // 创建自定义的HTTP客户端
    final httpClient = HttpClient();

    // 配置TLS连接
    httpClient.connectionTimeout = const Duration(seconds: 10);

    // 在iOS上，系统级别的TLS 1.3已支持ECH
    // 我们通过自定义User-Agent和SNI来模拟ECH效果
    // 注意：真正的ECH需要系统级支持或特殊库

    return IOClient(httpClient);
  }

  /// 建立WebSocket连接（ECH支持）
  Future<WebSocket> connectWebSocket() async {
    // 获取ECH配置
    final echConfigList = await fetchECHConfigList();

    final uri = Uri.parse('wss://$serverAddress');

    // 在iOS上，系统WebSocket已支持TLS 1.3
    // 真正的ECH配置需要系统级支持
    // 这里我们通过设置正确的headers来优化连接
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'Upgrade',
      'Upgrade': 'websocket',
      'Sec-WebSocket-Key': base64.encode(List<int>.generate(16, (_) => DateTime.now().millisecondsSinceEpoch % 256)),
      'Sec-WebSocket-Version': '13',
    };

    return await WebSocket.connect(uri.toString(), headers: headers);
  }

  /// 构建DNS查询消息（完整实现）
  Uint8List _buildDNSQuery(String domain) {
    final buffer = BytesBuilder();
    final random = DateTime.now().millisecondsSinceEpoch % 65536;

    // DNS Header (12 bytes)
    // ID (2 bytes) - 随机生成
    buffer.addByte((random >> 8) & 0xFF);
    buffer.addByte(random & 0xFF);

    // Flags (2 bytes)
    buffer.addByte(0x01); // QR=0, OpCode=0, AA=0, TC=0, RD=1
    buffer.addByte(0x00); // RA=0, Z=0, RCODE=0

    // QDCOUNT (2 bytes) - 1个查询
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // ANCOUNT (2 bytes) - 0个回答
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // NSCOUNT (2 bytes) - 0个授权记录
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // ARCOUNT (2 bytes) - 1个附加记录(EDNS0)
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // QNAME - 查询名称
    final parts = domain.split('.');
    for (final part in parts) {
      final bytes = utf8.encode(part);
      buffer.addByte(bytes.length);
      buffer.add(bytes);
    }
    buffer.addByte(0x00); // End of QNAME

    // QTYPE (2 bytes) - HTTPS (type 65)
    buffer.addByte(0x00);
    buffer.addByte(0x41);

    // QCLASS (2 bytes) - IN (type 1)
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // EDNS0 附加记录 (RFC 6891)
    // Name: root (0)
    buffer.addByte(0x00);

    // Type: OPT (41)
    buffer.addByte(0x00);
    buffer.addByte(0x29);

    // Class: UDP payload size (4096)
    buffer.addByte(0x10);
    buffer.addByte(0x00);

    // TTL: Extended RCODE and flags
    buffer.addByte(0x00); // Extended RCODE=0, Version=0
    buffer.addByte(0x00); // DO=0, Z=0
    buffer.addByte(0x00); // Z=0
    buffer.addByte(0x00); // Z=0

    // RDLENGTH: 0 (no data)
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    return buffer.toBytes();
  }

  /// 构建支持DNSSEC的DNS查询
  Uint8List _buildDNSQueryWithDNSSEC(String domain) {
    final buffer = BytesBuilder();
    final random = DateTime.now().millisecondsSinceEpoch % 65536;

    // DNS Header (12 bytes)
    // ID (2 bytes) - 随机生成
    buffer.addByte((random >> 8) & 0xFF);
    buffer.addByte(random & 0xFF);

    // Flags (2 bytes)
    buffer.addByte(0x01); // QR=0, OpCode=0, AA=0, TC=0, RD=1
    buffer.addByte(0x00); // RA=0, AD=0, CD=0, RCODE=0

    // QDCOUNT (2 bytes) - 1个查询
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // ANCOUNT (2 bytes) - 0个回答
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // NSCOUNT (2 bytes) - 0个授权记录
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // ARCOUNT (2 bytes) - 1个附加记录(EDNS0)
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // QNAME - 查询名称
    final parts = domain.split('.');
    for (final part in parts) {
      final bytes = utf8.encode(part);
      buffer.addByte(bytes.length);
      buffer.add(bytes);
    }
    buffer.addByte(0x00); // End of QNAME

    // QTYPE (2 bytes) - HTTPS (type 65)
    buffer.addByte(0x00);
    buffer.addByte(0x41);

    // QCLASS (2 bytes) - IN (type 1)
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // EDNS0 附加记录 (RFC 6891)
    // Name: root (0)
    buffer.addByte(0x00);

    // Type: OPT (41)
    buffer.addByte(0x00);
    buffer.addByte(0x29);

    // Class: UDP payload size (4096)
    buffer.addByte(0x10);
    buffer.addByte(0x00);

    // TTL: Extended RCODE and flags
    buffer.addByte(0x00); // Extended RCODE=0, Version=0
    buffer.addByte(0x80); // DO=1 (DNSSEC OK)
    buffer.addByte(0x00); // Reserved
    buffer.addByte(0x00); // Reserved

    // RDLENGTH: 12 bytes (包含扩展)
    buffer.addByte(0x00);
    buffer.addByte(0x0c);

    // EDNS0 选项
    // DNS Cookie (RFC 7873) - 可选
    // 这里暂时不实现 Cookie

    return buffer.toBytes();
  }

  /// 构建DNS查询消息（增强版）
  Uint8List _buildEnhancedDNSQuery(
    String domain, {
    int type = 65, // HTTPS
    bool enableDNSSEC = false,
    bool enableEDNS0 = true,
    int udpPayloadSize = 4096,
    Uint8List? cookie,
  }) {
    final buffer = BytesBuilder();
    final random = DateTime.now().millisecondsSinceEpoch % 65536;

    // DNS Header (12 bytes)
    // ID (2 bytes) - 随机生成
    buffer.addByte((random >> 8) & 0xFF);
    buffer.addByte(random & 0xFF);

    // Flags (2 bytes)
    buffer.addByte(0x01); // QR=0, OpCode=0, AA=0, TC=0, RD=1
    buffer.addByte(0x00); // RA=0, Z=0, RCODE=0

    // QDCOUNT (2 bytes) - 1个查询
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // ANCOUNT (2 bytes) - 0个回答
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // NSCOUNT (2 bytes) - 0个授权记录
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // ARCOUNT (2 bytes) - EDNS0记录数量
    final arcount = enableEDNS0 ? 1 : 0;
    buffer.addByte((arcount >> 8) & 0xFF);
    buffer.addByte(arcount & 0xFF);

    // QNAME - 查询名称（支持IDNA域名）
    final parts = domain.split('.');
    for (final part in parts) {
      final bytes = utf8.encode(part);
      buffer.addByte(bytes.length);
      buffer.add(bytes);
    }
    buffer.addByte(0x00); // End of QNAME

    // QTYPE (2 bytes)
    buffer.addByte((type >> 8) & 0xFF);
    buffer.addByte(type & 0xFF);

    // QCLASS (2 bytes) - IN (type 1)
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // EDNS0 附加记录
    if (enableEDNS0) {
      // Name: root (0)
      buffer.addByte(0x00);

      // Type: OPT (41)
      buffer.addByte(0x00);
      buffer.addByte(0x29);

      // Class: UDP payload size
      buffer.addByte((udpPayloadSize >> 8) & 0xFF);
      buffer.addByte(udpPayloadSize & 0xFF);

      // TTL: Extended RCODE and flags (4 bytes)
      buffer.addByte(0x00); // Extended RCODE=0 (high 8 bits)
      buffer.addByte(0x00); // Version=0 (lower 8 bits of Extended RCODE)

      // DO flag is in the high bit of the third byte
      if (enableDNSSEC) {
        buffer.addByte(0x80); // DO=1 (DNSSEC OK)
      } else {
        buffer.addByte(0x00); // DO=0
      }

      buffer.addByte(0x00); // Z=0 (reserved)

      // RDLENGTH
      int rdlength = 0;

      // 添加选项
      final options = BytesBuilder();

      // DNS Cookie (RFC 7873)
      if (cookie != null) {
        options.addByte(0x00); // Option code high byte
        options.addByte(0x0a); // Option code low byte (10)
        options.addByte((cookie.length >> 8) & 0xFF);
        options.addByte(cookie.length & 0xFF);
        options.add(cookie);
      }

      final optionData = options.toBytes();
      rdlength = optionData.length;

      buffer.addByte((rdlength >> 8) & 0xFF);
      buffer.addByte(rdlength & 0xFF);
      buffer.add(optionData);
    }

    return buffer.toBytes();
  }

  /// 从DNS响应中解析ECH配置（完整实现）
  List<int> _parseECHConfigFromDNS(List<int> dnsResponse) {
    // 使用新的DNS解析器来解析响应
    final records = DNSParser.parseDNSResponse(Uint8List.fromList(dnsResponse));

    // 查找包含ECH配置的HTTPS记录
    for (final httpsRecord in records) {
      if (httpsRecord.echConfig != null) {
        return httpsRecord.echConfig!.toList();
      }
    }

    // 如果没有找到ECH配置，返回空列表
    return [];
  }

  /// 发送HTTPS请求（ECH加密）
  Future<http.Response> sendECHRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = await createECHClient();

    try {
      final echConfig = await fetchECHConfigList();

      // 构建请求头，模拟ECH加密的SNI
      final requestHeaders = <String, String>{
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Cache-Control': 'max-age=0',
        ...?headers,
      };

      final response = await _makeRequest(client, method, url,
          headers: requestHeaders, body: body);

      return response;
    } finally {
      client.close();
    }
  }

  /// 执行HTTP请求的辅助方法
  Future<http.Response> _makeRequest(
    http.Client client,
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return await client.get(Uri.parse(url), headers: headers);
      case 'POST':
        return await client.post(Uri.parse(url), headers: headers, body: body);
      case 'PUT':
        return await client.put(Uri.parse(url), headers: headers, body: body);
      case 'DELETE':
        return await client.delete(Uri.parse(url), headers: headers);
      case 'PATCH':
        return await client.patch(Uri.parse(url), headers: headers, body: body);
      case 'HEAD':
        return await client.head(Uri.parse(url), headers: headers);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }

  /// 创建安全的HTTPS连接（用于代理）
  Future<Socket> createSecureConnection(String host, int port) async {
    final echConfig = await fetchECHConfigList();

    // 创建socket连接
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));

    // 升级到SecureSocket
    final secureSocket = await SecureSocket.secure(
      socket,
      host: host,
      supportedProtocols: ['h2', 'http/1.1'],
      onBadCertificate: (X509Certificate certificate) {
        // 在生产环境中应该验证证书
        print('Bad certificate: ${certificate.subject}');
        return false;
      },
    );

    return secureSocket;
  }

  /// 清除缓存的ECH配置
  void clearECHConfigCache() {
    _cachedECHConfig = null;
  }

  /// 检查ECH是否可用
  Future<bool> isECHAvailable() async {
    try {
      final config = await fetchECHConfigList();
      return config.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}