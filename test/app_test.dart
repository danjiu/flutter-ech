import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_ech_wk_ios/main.dart';
import 'package:vpn_ech_wk_ios/screens/home_screen.dart';

void main() {
  group('VPN App Tests', () {
    testWidgets('App should launch with HomeScreen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that HomeScreen is displayed
      expect(find.text('ECH VPN'), findsOneWidget);
      expect(find.text('快速连接'), findsOneWidget);
    });

    testWidgets('Should show server list', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Wait for the widget to load
      await tester.pumpAndSettle();

      // Look for server selector
      expect(find.text('服务器选择'), findsOneWidget);
      expect(find.text('添加服务器'), findsOneWidget);
    });
  });
}