import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../motion/motion_packet_decoder.dart';
import 'baton_transport.dart';

const batonServiceUuid = MotionPacketDecoder.serviceUuid;
const batonMotionUuid = MotionPacketDecoder.characteristicUuid;

/// Injectable BLE operations keep cancellation and lifecycle tests off hardware.
abstract interface class BatonBleBackend {
  bool get usesDevicePicker;
  Stream<BleDevice> get scanResults;
  Stream<AvailabilityState> get availabilityChanges;
  Future<BleDevice> requestDevice();
  Future<void> requestPermissions();
  Future<AvailabilityState> availability();
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connectDevice(String deviceId);
  Future<void> disconnectDevice(String deviceId);
  Future<void> discoverMotion(String deviceId);
  Future<void> subscribe(String deviceId);
  Future<void> unsubscribe(String deviceId);
  Stream<bool> connectionChanges(String deviceId);
  Stream<List<int>> values(String deviceId);
}

/// One user-selected (Web) or service-filtered (native) baton connection.
///
/// The constructor makes no platform calls. Connection is published only after
/// service discovery and notification subscription complete. Link operations
/// are serialized so cancellation of an old connect cannot tear down a newer
/// connection to the same physical device.
class UniversalBatonTransport implements BatonTransport {
  UniversalBatonTransport({
    BatonBleBackend? backend,
    this.scanTimeout = const Duration(seconds: 12),
  }) : _backend = backend ?? _UniversalBleBackend();

  final BatonBleBackend _backend;
  final Duration scanTimeout;
  final _connections = StreamController<BatonConnection>.broadcast(sync: true);
  final _packets = StreamController<List<int>>.broadcast(sync: true);
  BatonConnection _connection = const BatonConnection(
    status: BatonConnectionStatus.idle,
  );
  int _generation = 0;
  bool _disposed = false;
  bool _disposing = false;
  BleDevice? _device;
  StreamSubscription<bool>? _linkSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  StreamSubscription<AvailabilityState>? _availabilitySubscription;
  Completer<BleDevice>? _scanResult;
  Future<void> _linkTail = Future<void>.value();
  Future<void> _scanTail = Future<void>.value();

  @override
  BatonConnection get connection => _connection;
  @override
  Stream<BatonConnection> get connections => _connections.stream;
  @override
  Stream<List<int>> get packets => _packets.stream;

  bool _current(int generation) =>
      !_disposed && !_disposing && generation == _generation;

  void _emit(BatonConnection next) {
    if (_disposed) return;
    _connection = next;
    _connections.add(next);
  }

  @override
  Future<void> connect() {
    if (_disposed ||
        _disposing ||
        _connection.isBusy ||
        _connection.isConnected) {
      return Future<void>.value();
    }
    final generation = ++_generation;
    _emit(const BatonConnection(status: BatonConnectionStatus.scanning));
    // Invoke the browser chooser before the first await, preserving the tap's
    // transient user activation. Native scanning does not use that chooser.
    final selection = _backend.usesDevicePicker
        ? Future<BleDevice>.sync(_backend.requestDevice)
        : _findNativeDevice(generation);
    return _connectSelected(generation, selection);
  }

  Future<BleDevice> _findNativeDevice(int generation) async {
    await _backend.requestPermissions();
    if (!_current(generation)) throw const _Cancelled();
    final state = await _backend.availability();
    _checkAvailability(state);
    if (!_current(generation)) throw const _Cancelled();
    final result = Completer<BleDevice>();
    // Observe errors immediately, including cancellation while startScan waits.
    final selected = result.future;
    unawaited(
      selected.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    final scan = _scanTail.then((_) async {
      if (!_current(generation)) throw const _Cancelled();
      _scanResult = result;
      final subscription = _backend.scanResults.listen(
        (device) {
          if (_current(generation) && !result.isCompleted) {
            result.complete(device);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      );
      try {
        await _backend.startScan();
        if (!_current(generation)) throw const _Cancelled();
        return await selected.timeout(scanTimeout);
      } finally {
        if (identical(_scanResult, result)) _scanResult = null;
        await subscription.cancel();
        await _ignoreFailure(_backend.stopScan);
      }
    });
    _scanTail = scan.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return scan;
  }

  Future<void> _connectSelected(
    int generation,
    Future<BleDevice> selection,
  ) async {
    try {
      final selected = await selection;
      if (!_current(generation)) return;
      await _runLink(() async {
        if (!_current(generation)) return;
        _device = selected;
        _emit(
          BatonConnection(
            status: BatonConnectionStatus.connecting,
            deviceName: selected.name ?? 'Rehab Rhapsody',
          ),
        );
        var established = false;
        _linkSubscription = _backend
            .connectionChanges(selected.deviceId)
            .listen(
              (connected) {
                if (!connected && established && _current(generation)) {
                  _linkLost(
                    'Baton disconnected. Keep it nearby and reconnect.',
                  );
                }
              },
              onError: (Object _, StackTrace _) {
                if (_current(generation)) {
                  _linkLost('Baton connection was lost.');
                }
              },
            );
        await _backend.connectDevice(selected.deviceId);
        established = true;
        if (!_current(generation)) {
          await _ignoreFailure(
            () => _backend.disconnectDevice(selected.deviceId),
          );
          return;
        }
        await _backend.discoverMotion(selected.deviceId);
        if (!_current(generation)) return;
        _valueSubscription = _backend
            .values(selected.deviceId)
            .listen(
              (value) {
                if (_current(generation) && _connection.isConnected) {
                  _packets.add(List<int>.unmodifiable(value));
                }
              },
              onError: (Object _, StackTrace _) {
                if (_current(generation)) {
                  _linkLost(
                    'Motion stream was interrupted. Reconnect the baton.',
                  );
                }
              },
            );
        await _backend.subscribe(selected.deviceId);
        if (!_current(generation)) return;
        _watchAvailability(generation);
        _emit(
          BatonConnection(
            status: BatonConnectionStatus.connected,
            deviceName: selected.name ?? 'Rehab Rhapsody',
          ),
        );
      });
    } catch (error) {
      if (_current(generation)) {
        ++_generation;
        _emit(_failureState(error));
        await _cleanup();
      }
    }
  }

  void _watchAvailability(int generation) {
    _availabilitySubscription = _backend.availabilityChanges.listen(
      (state) {
        if (!_current(generation)) return;
        if (state == AvailabilityState.poweredOff) {
          _linkLost('Bluetooth is off. Turn it on, then reconnect.');
        } else if (state == AvailabilityState.unauthorized) {
          _linkLost('Allow Bluetooth access in Settings, then reconnect.');
        }
      },
      onError: (Object _, StackTrace _) {
        if (_current(generation)) _linkLost('Bluetooth became unavailable.');
      },
    );
  }

  void _linkLost(String message) {
    ++_generation;
    _emit(
      BatonConnection(
        status: BatonConnectionStatus.disconnected,
        deviceName: _device?.name,
        message: message,
      ),
    );
    unawaited(_cleanup());
  }

  Future<void> _runLink(Future<void> Function() action) {
    final operation = _linkTail.then((_) => action());
    _linkTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _cleanup() async {
    final device = _device;
    _device = null;
    final link = _linkSubscription;
    final values = _valueSubscription;
    final availability = _availabilitySubscription;
    _linkSubscription = null;
    _valueSubscription = null;
    _availabilitySubscription = null;
    await Future.wait([
      if (link != null) link.cancel(),
      if (values != null) values.cancel(),
      if (availability != null) availability.cancel(),
    ]);
    if (device != null) {
      await _runLink(() async {
        await _ignoreFailure(() => _backend.unsubscribe(device.deviceId));
        await _ignoreFailure(() => _backend.disconnectDevice(device.deviceId));
      });
    }
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    ++_generation;
    final pending = _scanResult;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const _Cancelled());
    }
    _emit(const BatonConnection(status: BatonConnectionStatus.disconnected));
    await _cleanup();
    await _scanTail;
  }

  @override
  Future<void> dispose() async {
    if (_disposed || _disposing) return;
    _disposing = true;
    await disconnect();
    _disposed = true;
    await _connections.close();
    await _packets.close();
  }

  static Future<void> _ignoreFailure(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Already-disconnected devices and cancelled scans need no retry queue.
    }
  }

  static void _checkAvailability(AvailabilityState state) {
    if (state == AvailabilityState.unsupported) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.notSupported,
        message: 'Unsupported',
      );
    }
    if (state == AvailabilityState.unauthorized) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.bluetoothUnauthorized,
        message: 'Permission denied',
      );
    }
    if (state == AvailabilityState.poweredOff) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.bluetoothNotEnabled,
        message: 'Bluetooth off',
      );
    }
  }

  static BatonConnection _failureState(Object error) {
    if (error is _Cancelled) {
      return const BatonConnection(status: BatonConnectionStatus.disconnected);
    }
    if (error is TimeoutException) {
      return const BatonConnection(
        status: BatonConnectionStatus.error,
        message: 'No baton found. Keep it powered and disconnect LightBlue, then try again.',
      );
    }
    if (error is UnsupportedError) {
      return const BatonConnection(
        status: BatonConnectionStatus.unsupported,
        message: 'Use Chrome or Edge on a computer, or the iPhone app, for Bluetooth.',
      );
    }
    // Web Bluetooth's chooser cancellation may be surfaced by its browser
    // dependency as an Error rather than UniversalBleException.
    final description = error.toString().toLowerCase();
    if (description.contains('cancelled') || description.contains('canceled')) {
      return const BatonConnection(
        status: BatonConnectionStatus.disconnected,
        message: 'Connection cancelled. Choose the baton to connect.',
      );
    }
    if (error is UniversalBleException) {
      switch (error.code) {
        case UniversalBleErrorCode.notSupported:
        case UniversalBleErrorCode.notImplemented:
        case UniversalBleErrorCode.webBluetoothGloballyDisabled:
          return const BatonConnection(
            status: BatonConnectionStatus.unsupported,
            message: 'Use Chrome or Edge on a computer, or the iPhone app, for Bluetooth.',
          );
        case UniversalBleErrorCode.bluetoothNotAllowed:
        case UniversalBleErrorCode.bluetoothUnauthorized:
        case UniversalBleErrorCode.accessDenied:
          return const BatonConnection(
            status: BatonConnectionStatus.error,
            message: 'Allow Bluetooth access in Settings, then try again.',
          );
        case UniversalBleErrorCode.bluetoothNotEnabled:
        case UniversalBleErrorCode.bluetoothNotAvailable:
          return const BatonConnection(
            status: BatonConnectionStatus.error,
            message: 'Turn on Bluetooth, then try again.',
          );
        case UniversalBleErrorCode.operationCancelled:
          return const BatonConnection(
            status: BatonConnectionStatus.disconnected,
            message: 'Connection cancelled. Choose the baton to connect.',
          );
        case UniversalBleErrorCode.serviceNotFound:
        case UniversalBleErrorCode.characteristicNotFound:
        case UniversalBleErrorCode.characteristicDoesNotSupportNotify:
          return const BatonConnection(
            status: BatonConnectionStatus.error,
            message:
                'Upload the BLE motion sketch to this baton, then reconnect.',
          );
        default:
          break;
      }
    }
    return const BatonConnection(
      status: BatonConnectionStatus.error,
      message: 'Could not connect. Keep the baton powered, disconnect LightBlue, and try again.',
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

class _UniversalBleBackend implements BatonBleBackend {
  @override
  bool get usesDevicePicker => kIsWeb;
  @override
  Stream<BleDevice> get scanResults => UniversalBle.scanStream;
  @override
  Stream<AvailabilityState> get availabilityChanges =>
      UniversalBle.availabilityStream;
  @override
  Future<BleDevice> requestDevice() => UniversalBle.requestDevice(
    scanFilter: ScanFilter(withServices: [batonServiceUuid]),
  );
  @override
  Future<void> requestPermissions() => UniversalBle.requestPermissions();
  @override
  Future<AvailabilityState> availability() =>
      UniversalBle.getBluetoothAvailabilityState();
  @override
  Future<void> startScan() => UniversalBle.startScan(
    scanFilter: ScanFilter(withServices: [batonServiceUuid]),
  );
  @override
  Future<void> stopScan() => UniversalBle.stopScan();
  @override
  Future<void> connectDevice(String deviceId) =>
      UniversalBle.connect(deviceId, timeout: const Duration(seconds: 15));
  @override
  Future<void> disconnectDevice(String deviceId) =>
      UniversalBle.disconnect(deviceId, timeout: const Duration(seconds: 3));
  @override
  Future<void> discoverMotion(String deviceId) async {
    final services = await UniversalBle.discoverServices(deviceId);
    final matches = services.where(
      (s) => s.uuid.toLowerCase() == batonServiceUuid,
    );
    if (matches.isEmpty) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.serviceNotFound,
        message: 'Motion service not found',
      );
    }
    final characteristics = matches.first.characteristics.where(
      (c) => c.uuid.toLowerCase() == batonMotionUuid,
    );
    if (characteristics.isEmpty) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.characteristicNotFound,
        message: 'Motion characteristic not found',
      );
    }
    if (!characteristics.first.properties.contains(
      CharacteristicProperty.notify,
    )) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.characteristicDoesNotSupportNotify,
        message: 'Motion notifications unavailable',
      );
    }
  }

  @override
  Future<void> subscribe(String deviceId) =>
      UniversalBle.subscribeNotifications(
        deviceId,
        batonServiceUuid,
        batonMotionUuid,
      );
  @override
  Future<void> unsubscribe(String deviceId) => UniversalBle.unsubscribe(
    deviceId,
    batonServiceUuid,
    batonMotionUuid,
    timeout: const Duration(seconds: 3),
  );
  @override
  Stream<bool> connectionChanges(String deviceId) =>
      UniversalBle.connectionStream(deviceId);
  @override
  Stream<List<int>> values(String deviceId) =>
      UniversalBle.characteristicValueStream(deviceId, batonMotionUuid);
}
