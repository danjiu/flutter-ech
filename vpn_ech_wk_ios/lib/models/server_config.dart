import 'package:json_annotation/json_annotation.dart';

part 'server_config.g.dart';

@JsonSerializable()
class ServerConfig {
  final String id;
  final String name;
  @JsonKey(name: 'server_address')
  final String serverAddress;
  final int port;
  @JsonKey(name: 'preferred_ip')
  final String? preferredIp;
  final String? token;
  @JsonKey(name: 'dns_server')
  final String? dnsServer;
  @JsonKey(name: 'ech_domain')
  final String? echDomain;
  @JsonKey(name: 'routing_mode')
  final RoutingMode routingMode;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'last_connected')
  final DateTime? lastConnected;
  @JsonKey(name: 'connection_count')
  final int connectionCount;

  ServerConfig({
    required this.id,
    required this.name,
    required this.serverAddress,
    this.port = 443,
    this.preferredIp,
    this.token,
    this.dnsServer = 'dns.alidns.com/dns-query',
    this.echDomain = 'cloudflare-ech.com',
    this.routingMode = RoutingMode.global,
    this.isActive = false,
    required this.createdAt,
    this.lastConnected,
    this.connectionCount = 0,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) =>
      _$ServerConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ServerConfigToJson(this);

  ServerConfig copyWith({
    String? id,
    String? name,
    String? serverAddress,
    int? port,
    String? preferredIp,
    String? token,
    String? dnsServer,
    String? echDomain,
    RoutingMode? routingMode,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastConnected,
    int? connectionCount,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      serverAddress: serverAddress ?? this.serverAddress,
      port: port ?? this.port,
      preferredIp: preferredIp ?? this.preferredIp,
      token: token ?? this.token,
      dnsServer: dnsServer ?? this.dnsServer,
      echDomain: echDomain ?? this.echDomain,
      routingMode: routingMode ?? this.routingMode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
      connectionCount: connectionCount ?? this.connectionCount,
    );
  }
}

enum RoutingMode {
  @JsonValue('global')
  global,
  @JsonValue('bypass_cn')
  bypassCn,
  @JsonValue('none')
  none,
}

extension RoutingModeExtension on RoutingMode {
  String get displayName {
    switch (this) {
      case RoutingMode.global:
        return '全局代理';
      case RoutingMode.bypassCn:
        return '跳过中国大陆';
      case RoutingMode.none:
        return '直连模式';
    }
  }

  String get description {
    switch (this) {
      case RoutingMode.global:
        return '所有流量都走代理';
      case RoutingMode.bypassCn:
        return '中国IP直连，其他走代理';
      case RoutingMode.none:
        return '所有流量直连';
    }
  }
}