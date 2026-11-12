/// Connection state comes from the transport, independently of motion validity.
enum BatonConnectionStatus {
  idle,
  scanning,
  connecting,
  connected,
  disconnected,
  unsupported,
  error,
}

final class BatonConnection {
  const BatonConnection({required this.status, this.deviceName, this.message});

  final BatonConnectionStatus status;
  final String? deviceName;
  final String? message;

  bool get isConnected => status == BatonConnectionStatus.connected;
  bool get isBusy =>
      status == BatonConnectionStatus.scanning ||
      status == BatonConnectionStatus.connecting;
}

/// A transport never turns incoming motion into playback by itself.
///
/// [connect] must be called directly from a user action: on Web it opens the
/// browser's Bluetooth chooser. Implementations discard packets from cancelled
/// or previous connections, and do not automatically reconnect or resume play.
abstract interface class BatonTransport {
  BatonConnection get connection;
  Stream<BatonConnection> get connections;
  Stream<List<int>> get packets;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> dispose();
}
