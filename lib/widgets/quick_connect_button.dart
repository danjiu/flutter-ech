import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/vpn_state.dart';
import '../models/server_config.dart';

class QuickConnectButton extends StatefulWidget {
  final VpnConnectionState vpnState;
  final ServerConfig? selectedServer;
  final VoidCallback onPressed;

  const QuickConnectButton({
    Key? key,
    required this.vpnState,
    this.selectedServer,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<QuickConnectButton> createState() => _QuickConnectButtonState();
}

class _QuickConnectButtonState extends State<QuickConnectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.vpnState.isConnected;
    final isTransitioning = widget.vpnState.isTransitioning;
    final buttonColor = isConnected ? Colors.red : Colors.green;
    final icon = isConnected ? Icons.stop : Icons.play_arrow;
    final text = isConnected ? '断开连接' : '快速连接';

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isTransitioning ? null : _handleButtonPress,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(24),
                elevation: 8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isTransitioning
                      ? SpinKitThreeBounce(
                          color: Colors.white,
                          size: 24,
                        )
                      : Icon(
                          icon,
                          size: 48,
                        ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleButtonPress() async {
    if (widget.selectedServer == null && !widget.vpnState.isConnected) {
      _showError('请先选择一个服务器');
      return;
    }

    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _animationController.reverse();

    widget.onPressed();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}