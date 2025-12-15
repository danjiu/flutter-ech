// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerConfig _$ServerConfigFromJson(Map<String, dynamic> json) => ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      serverAddress: json['server_address'] as String,
      port: json['port'] as int? ?? 443,
      preferredIp: json['preferred_ip'] as String?,
      token: json['token'] as String?,
      dnsServer: json['dns_server'] as String?,
      echDomain: json['ech_domain'] as String?,
      routingMode: $enumDecode(_$RoutingModeEnumMap, json['routing_mode']),
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastConnected: json['last_connected'] == null
          ? null
          : DateTime.parse(json['last_connected'] as String),
      connectionCount: json['connection_count'] as int? ?? 0,
    );

Map<String, dynamic> _$ServerConfigToJson(ServerConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'server_address': instance.serverAddress,
      'port': instance.port,
      'preferred_ip': instance.preferredIp,
      'token': instance.token,
      'dns_server': instance.dnsServer,
      'ech_domain': instance.echDomain,
      'routing_mode': _$RoutingModeEnumMap[instance.routingMode]!,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'last_connected': instance.lastConnected?.toIso8601String(),
      'connection_count': instance.connectionCount,
    };

const _$RoutingModeEnumMap = {
  RoutingMode.global: 'global',
  RoutingMode.bypassCn: 'bypass_cn',
  RoutingMode.none: 'none',
};