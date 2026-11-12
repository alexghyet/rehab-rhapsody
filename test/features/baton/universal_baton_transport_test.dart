import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_rhapsody/features/baton/baton_transport.dart';
import 'package:rehab_rhapsody/features/baton/universal_baton_transport.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  test('idle disconnect and disposal never call a platform plugin', () async {
    final backend = _FakeBackend();
    final transport = UniversalBatonTransport(backend: backend);
    await transport.disconnect();
    await transport.dispose();
    await transport.dispose();
    expect(backend.calls, isEmpty);
    await backend.dispose();
  });

  test(
    'construction is lazy and chooser starts in the calling gesture',
    () async {
      final backend = _FakeBackend();
      final transport = UniversalBatonTransport(backend: backend);
      expect(backend.calls, isEmpty);
      expect(transport.connection.status, BatonConnectionStatus.idle);

      final connecting = transport.connect();
      expect(backend.calls, ['chooser']);
      await connecting;
      expect(transport.connection.isConnected, isTrue);
      expect(backend.calls, ['chooser', 'connect', 'discover', 'subscribe']);
      await transport.dispose();
      await backend.dispose();
    },
  );

  test(
    'connection is not ready until notification subscription succeeds',
    () async {
      final backend = _FakeBackend()..subscriptionGate = Completer<void>();
      final transport = UniversalBatonTransport(backend: backend);
      final received = <List<int>>[];
      final packets = transport.packets.listen(received.add);
      final connecting = transport.connect();
      await _flush();
      expect(transport.connection.status, BatonConnectionStatus.connecting);
      backend.motion.add([1, 2]);
      expect(received, isEmpty);

      backend.subscriptionGate!.complete();
      await connecting;
      backend.motion.add([3, 4]);
      expect(received, [
        [3, 4],
      ]);
      await packets.cancel();
      await transport.dispose();
      await backend.dispose();
    },
  );

  test(
    'cancelled browser chooser cannot connect after its late result',
    () async {
      final backend = _FakeBackend()..selectionGate = Completer<BleDevice>();
      final transport = UniversalBatonTransport(backend: backend);
      final connecting = transport.connect();
      await transport.disconnect();
      backend.selectionGate!.complete(_device);
      await connecting;

      expect(transport.connection.status, BatonConnectionStatus.disconnected);
      expect(backend.calls, ['chooser']);
      await transport.dispose();
      await backend.dispose();
    },
  );

  test(
    'unsupported Web Bluetooth gives a supported-platform instruction',
    () async {
      final backend = _FakeBackend()..selectionGate = Completer<BleDevice>();
      final transport = UniversalBatonTransport(backend: backend);
      final connecting = transport.connect();
      backend.selectionGate!.completeError(UnsupportedError('requestDevice'));
      await connecting;
      expect(transport.connection.status, BatonConnectionStatus.unsupported);
      expect(transport.connection.message, contains('Chrome or Edge'));
      await transport.dispose();
      await backend.dispose();
    },
  );

  test('disposing during the chooser ignores its later selection', () async {
    final backend = _FakeBackend()..selectionGate = Completer<BleDevice>();
    final transport = UniversalBatonTransport(backend: backend);
    final connecting = transport.connect();
    await transport.dispose();
    backend.selectionGate!.complete(_device);
    await connecting;
    await transport.connect();
    expect(backend.calls, ['chooser']);
    await backend.dispose();
  });

  test(
    'cancelled native connect is cleaned before reconnecting same device',
    () async {
      final gate = Completer<void>();
      final backend = _FakeBackend()..connectionGate = gate;
      final transport = UniversalBatonTransport(backend: backend);
      final first = transport.connect();
      await _flush();
      expect(backend.calls, ['chooser', 'connect']);

      final disconnecting = transport.disconnect();
      final second = transport.connect();
      gate.complete();
      await Future.wait([first, disconnecting, second]);
      expect(transport.connection.isConnected, isTrue);
      final secondConnect = backend.calls.lastIndexOf('connect');
      expect(backend.calls.indexOf('disconnect'), lessThan(secondConnect));
      await transport.dispose();
      await backend.dispose();
    },
  );

  test(
    'link loss clears connection and ignores further notification values',
    () async {
      final backend = _FakeBackend();
      final transport = UniversalBatonTransport(backend: backend);
      final received = <List<int>>[];
      final packets = transport.packets.listen(received.add);
      await transport.connect();
      backend.motion.add([1]);
      backend.link.add(false);
      backend.motion.add([2]);

      expect(transport.connection.status, BatonConnectionStatus.disconnected);
      expect(received, [
        [1],
      ]);
      await packets.cancel();
      await transport.dispose();
      await backend.dispose();
    },
  );

  test(
    'permission denial produces an actionable error before scanning',
    () async {
      final backend = _FakeBackend()
        ..picker = false
        ..permissionError = UniversalBleException(
          code: UniversalBleErrorCode.bluetoothUnauthorized,
          message: 'Denied',
        );
      final transport = UniversalBatonTransport(backend: backend);
      await transport.connect();
      expect(transport.connection.status, BatonConnectionStatus.error);
      expect(transport.connection.message, contains('Allow Bluetooth access'));
      expect(backend.calls, ['permissions']);
      await transport.dispose();
      await backend.dispose();
    },
  );

  test(
    'native scan timeout stops scanning without announcing a link',
    () async {
      final backend = _FakeBackend()..picker = false;
      final transport = UniversalBatonTransport(
        backend: backend,
        scanTimeout: const Duration(milliseconds: 1),
      );
      await transport.connect();
      expect(transport.connection.status, BatonConnectionStatus.error);
      expect(transport.connection.message, contains('No baton found'));
      expect(backend.calls, contains('stopScan'));
      expect(backend.calls, isNot(contains('connect')));
      await transport.dispose();
      await backend.dispose();
    },
  );

  test('native scan cancellation does not leave an active scan', () async {
    final backend = _FakeBackend()..picker = false;
    final transport = UniversalBatonTransport(backend: backend);
    final connecting = transport.connect();
    await _flush();
    expect(backend.calls, contains('startScan'));
    await transport.disconnect();
    await connecting;
    expect(backend.calls.last, 'stopScan');
    expect(transport.connection.status, BatonConnectionStatus.disconnected);
    await transport.dispose();
    await backend.dispose();
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final _device = BleDevice(deviceId: 'baton', name: 'Rehab Rhapsody');

class _FakeBackend implements BatonBleBackend {
  final calls = <String>[];
  final motion = StreamController<List<int>>.broadcast(sync: true);
  final link = StreamController<bool>.broadcast(sync: true);
  final scan = StreamController<BleDevice>.broadcast(sync: true);
  final availabilityController =
      StreamController<AvailabilityState>.broadcast();
  bool picker = true;
  Object? permissionError;
  Completer<BleDevice>? selectionGate;
  Completer<void>? connectionGate;
  Completer<void>? subscriptionGate;

  @override
  bool get usesDevicePicker => picker;
  @override
  Stream<BleDevice> get scanResults => scan.stream;
  @override
  Stream<AvailabilityState> get availabilityChanges =>
      availabilityController.stream;
  @override
  Future<BleDevice> requestDevice() {
    calls.add('chooser');
    return selectionGate?.future ?? Future.value(_device);
  }

  @override
  Future<void> requestPermissions() async {
    calls.add('permissions');
    if (permissionError != null) throw permissionError!;
  }

  @override
  Future<AvailabilityState> availability() async => AvailabilityState.poweredOn;
  @override
  Future<void> startScan() async => calls.add('startScan');
  @override
  Future<void> stopScan() async => calls.add('stopScan');
  @override
  Future<void> connectDevice(String deviceId) async {
    calls.add('connect');
    await connectionGate?.future;
  }

  @override
  Future<void> disconnectDevice(String deviceId) async =>
      calls.add('disconnect');
  @override
  Future<void> discoverMotion(String deviceId) async => calls.add('discover');
  @override
  Future<void> subscribe(String deviceId) async {
    calls.add('subscribe');
    await subscriptionGate?.future;
  }

  @override
  Future<void> unsubscribe(String deviceId) async => calls.add('unsubscribe');
  @override
  Stream<bool> connectionChanges(String deviceId) => link.stream;
  @override
  Stream<List<int>> values(String deviceId) => motion.stream;

  Future<void> dispose() async {
    await motion.close();
    await link.close();
    await scan.close();
    await availabilityController.close();
  }
}
