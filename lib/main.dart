import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'screens/server_config_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';
import 'screens/privacy_screen.dart';
import 'services/vpn_service.dart';
import 'services/storage_service.dart';
import 'utils/logger.dart';
import 'models/server_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置应用方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 请求必要权限
  await _requestPermissions();

  // 初始化服务
  await _initializeServices();

  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  // 请求位置权限（用于网络状态判断）
  if (await Permission.locationWhenInUse.isDenied) {
    await Permission.locationWhenInUse.request();
  }

  // 请求存储权限（Android）
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }

  // 请求通知权限
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // 请求VPN权限（iOS）
  if (await Permission.vpn.isDenied) {
    await Permission.vpn.request();
  }

  // VPN权限通常在iOS中通过其他方式处理，不需要特殊的权限
  // VPN配置会触发系统权限对话框
}

Future<void> _initializeServices() async {
  try {
    // 初始化VPN服务
    await VpnService().initialize();

    // 初始化存储服务
    await StorageService().getServerConfigs();

    AppLogger.i('Services initialized successfully');
  } catch (e) {
    AppLogger.e('Failed to initialize services: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECH VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue[600],
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue[600],
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[800],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      routes: {
        '/add_server': (context) => const ServerConfigScreen(),
        '/edit_server': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is ServerConfig) {
            return ServerConfigScreen(server: args);
          }
          return const ServerConfigScreen();
        },
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
        '/privacy': (context) => const PrivacyScreen(),
      },
    );
  }
}
