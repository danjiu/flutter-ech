import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/server_config.dart';
import 'vpn_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const _secureStorage = FlutterSecureStorage();
  static const _serverConfigsKey = 'server_configs';
  static const _activeServerKey = 'active_server';
  static const _connectionHistoryKey = 'connection_history';
  static const _appSettingsKey = 'app_settings';

  final Logger _logger = Logger();

  // 服务器配置管理
  Future<List<ServerConfig>> getServerConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = prefs.getString(_serverConfigsKey);

      if (configsJson == null) {
        // 返回默认配置
        final defaultConfigs = [
          ServerConfig(
            id: 'default',
            name: '默认服务器',
            serverAddress: 'your-worker.workers.dev',
            port: 443,
            routingMode: RoutingMode.global,
            createdAt: DateTime.now(),
          ),
        ];
        await saveServerConfigs(defaultConfigs);
        return defaultConfigs;
      }

      final List<dynamic> configsList = json.decode(configsJson);
      return configsList.map((json) => ServerConfig.fromJson(json)).toList();
    } catch (e) {
      _logger.e('Failed to get server configs: $e');
      return [];
    }
  }

  Future<void> saveServerConfigs(List<ServerConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = json.encode(
        configs.map((config) => config.toJson()).toList(),
      );
      await prefs.setString(_serverConfigsKey, configsJson);
    } catch (e) {
      _logger.e('Failed to save server configs: $e');
    }
  }

  Future<void> saveServerConfig(ServerConfig config) async {
    try {
      final configs = await getServerConfigs();
      final index = configs.indexWhere((c) => c.id == config.id);

      if (index >= 0) {
        configs[index] = config;
      } else {
        configs.add(config);
      }

      await saveServerConfigs(configs);
    } catch (e) {
      _logger.e('Failed to save server config: $e');
    }
  }

  Future<void> deleteServerConfig(String configId) async {
    try {
      final configs = await getServerConfigs();
      configs.removeWhere((config) => config.id == configId);
      await saveServerConfigs(configs);
    } catch (e) {
      _logger.e('Failed to delete server config: $e');
    }
  }

  Future<ServerConfig?> getActiveServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverId = prefs.getString(_activeServerKey);

      if (serverId == null) return null;

      final configs = await getServerConfigs();
      try {
        return configs.firstWhere((config) => config.id == serverId);
      } catch (e) {
        return null;
      }
    } catch (e) {
      _logger.e('Failed to get active server: $e');
      return null;
    }
  }

  Future<void> setActiveServer(String serverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeServerKey, serverId);
    } catch (e) {
      _logger.e('Failed to set active server: $e');
    }
  }

  // 安全存储 - 用于存储敏感信息如 Token
  Future<void> saveToken(String serverId, String token) async {
    try {
      await _secureStorage.write(
        key: 'token_$serverId',
        value: token,
      );
    } catch (e) {
      _logger.e('Failed to save token: $e');
    }
  }

  Future<String?> getToken(String serverId) async {
    try {
      return await _secureStorage.read(key: 'token_$serverId');
    } catch (e) {
      _logger.e('Failed to get token: $e');
      return null;
    }
  }

  Future<void> deleteToken(String serverId) async {
    try {
      await _secureStorage.delete(key: 'token_$serverId');
    } catch (e) {
      _logger.e('Failed to delete token: $e');
    }
  }

  // 连接历史记录
  Future<void> saveConnectionStats(Map<String, dynamic> stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_connectionHistoryKey) ?? '[]';
      final List<dynamic> history = json.decode(historyJson);

      history.add({
        ...stats,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 只保留最近100条记录
      if (history.length > 100) {
        history.removeRange(0, history.length - 100);
      }

      await prefs.setString(_connectionHistoryKey, json.encode(history));
    } catch (e) {
      _logger.e('Failed to save connection stats: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getConnectionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_connectionHistoryKey) ?? '[]';
      final List<dynamic> history = json.decode(historyJson);
      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      _logger.e('Failed to get connection history: $e');
      return [];
    }
  }

  // 应用设置
  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_appSettingsKey);

      if (settingsJson == null) {
        return _getDefaultSettings();
      }

      return Map<String, dynamic>.from(json.decode(settingsJson));
    } catch (e) {
      _logger.e('Failed to get app settings: $e');
      return _getDefaultSettings();
    }
  }

  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appSettingsKey, json.encode(settings));
    } catch (e) {
      _logger.e('Failed to save app settings: $e');
    }
  }

  Map<String, dynamic> _getDefaultSettings() {
    return {
      'auto_connect': false,
      'notifications': true,
      'dark_mode': false,
      'language': 'zh_CN',
      'log_level': 'info',
      'connection_timeout': 30,
      'retry_count': 3,
    };
  }

  // 清理所有数据
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _secureStorage.deleteAll();
      _logger.i('All data cleared');
    } catch (e) {
      _logger.e('Failed to clear all data: $e');
    }
  }

  // 导出配置
  Future<String> exportConfigs() async {
    try {
      final configs = await getServerConfigs();
      final settings = await getAppSettings();

      final exportData = {
        'version': '1.0.0',
        'exported_at': DateTime.now().toIso8601String(),
        'configs': configs.map((c) => c.toJson()).toList(),
        'settings': settings,
      };

      return json.encode(exportData);
    } catch (e) {
      _logger.e('Failed to export configs: $e');
      rethrow;
    }
  }

  // 导入配置
  Future<void> importConfigs(String jsonData) async {
    try {
      final data = json.decode(jsonData);
      final List<dynamic> configsData = data['configs'] ?? [];

      final configs = configsData.map((json) => ServerConfig.fromJson(json)).toList();
      await saveServerConfigs(configs);

      if (data['settings'] != null) {
        await saveAppSettings(Map<String, dynamic>.from(data['settings']));
      }

      _logger.i('Configs imported successfully');
    } catch (e) {
      _logger.e('Failed to import configs: $e');
      rethrow;
    }
  }
}