enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

extension VpnConnectionStateExtension on VpnConnectionState {
  String get displayName {
    switch (this) {
      case VpnConnectionState.disconnected:
        return '已断开';
      case VpnConnectionState.connecting:
        return '连接中';
      case VpnConnectionState.connected:
        return '已连接';
      case VpnConnectionState.disconnecting:
        return '断开中';
      case VpnConnectionState.error:
        return '错误';
    }
  }

  bool get isConnected => this == VpnConnectionState.connected;
  bool get isConnecting => this == VpnConnectionState.connecting;
  bool get isDisconnected => this == VpnConnectionState.disconnected;
  bool get isTransitioning =>
      this == VpnConnectionState.connecting ||
      this == VpnConnectionState.disconnecting;
}