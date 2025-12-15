// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionStats _$ConnectionStatsFromJson(Map<String, dynamic> json) =>
    ConnectionStats(
      bytesUploaded: json['bytes_uploaded'] as int? ?? 0,
      bytesDownloaded: json['bytes_downloaded'] as int? ?? 0,
      connectionDuration: json['connection_duration'] as int? ?? 0,
      connectedAt: json['connected_at'] == null
          ? null
          : DateTime.parse(json['connected_at'] as String),
      serverAddress: json['server_address'] as String?,
    );

Map<String, dynamic> _$ConnectionStatsToJson(ConnectionStats instance) =>
    <String, dynamic>{
      'bytes_uploaded': instance.bytesUploaded,
      'bytes_downloaded': instance.bytesDownloaded,
      'connection_duration': instance.connectionDuration,
      'connected_at': instance.connectedAt?.toIso8601String(),
      'server_address': instance.serverAddress,
    };