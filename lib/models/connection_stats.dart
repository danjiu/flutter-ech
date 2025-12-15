import 'package:json_annotation/json_annotation.dart';

part 'connection_stats.g.dart';

@JsonSerializable()
class ConnectionStats {
  @JsonKey(name: 'bytes_uploaded')
  final int bytesUploaded;
  @JsonKey(name: 'bytes_downloaded')
  final int bytesDownloaded;
  @JsonKey(name: 'connection_duration')
  final int connectionDuration;
  @JsonKey(name: 'connected_at')
  final DateTime? connectedAt;
  @JsonKey(name: 'server_address')
  final String? serverAddress;

  ConnectionStats({
    this.bytesUploaded = 0,
    this.bytesDownloaded = 0,
    this.connectionDuration = 0,
    this.connectedAt,
    this.serverAddress,
  });

  factory ConnectionStats.fromJson(Map<String, dynamic> json) =>
      _$ConnectionStatsFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionStatsToJson(this);

  String get uploadSpeedFormatted {
    return _formatBytes(bytesUploaded);
  }

  String get downloadSpeedFormatted {
    return _formatBytes(bytesDownloaded);
  }

  String get durationFormatted {
    final duration = Duration(seconds: connectionDuration);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  static String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(2)} ${units[unitIndex]}';
  }
}