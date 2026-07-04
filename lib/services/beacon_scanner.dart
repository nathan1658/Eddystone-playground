import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/beacon_device.dart';
import 'beacon_parser.dart';

abstract class BeaconScanner extends ChangeNotifier {
  List<BeaconDevice> get devices;

  bool get isScanning;

  String get statusText;

  bool get isSupported;

  Future<void> start();

  Future<void> refresh();

  Future<void> stop();
}

class FlutterBeaconScanner extends BeaconScanner {
  FlutterBeaconScanner({BeaconParser? parser})
    : _parser = parser ?? BeaconParser();

  static const _scanUiUpdateInterval = Duration(milliseconds: 900);

  final BeaconParser _parser;
  final Map<String, BeaconDevice> _devices = {};
  final Map<String, int> _deviceRanks = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _refreshTimer;
  Timer? _pendingScanNotify;
  DateTime? _lastScanNotifyAt;
  int _nextDeviceRank = 0;
  bool _isScanning = false;
  bool _isSupported = true;
  String _statusText = 'Starting Bluetooth scan';

  @override
  List<BeaconDevice> get devices {
    final sorted = _devices.values.toList()
      ..sort((a, b) {
        final byRank = (_deviceRanks[a.id] ?? 0).compareTo(
          _deviceRanks[b.id] ?? 0,
        );
        if (byRank != 0) {
          return byRank;
        }
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  @override
  bool get isScanning => _isScanning;

  @override
  String get statusText => _statusText;

  @override
  bool get isSupported => _isSupported;

  @override
  Future<void> start() async {
    _isSupported = await FlutterBluePlus.isSupported;
    if (!_isSupported) {
      _statusText = 'Bluetooth LE is not supported on this device';
      _notifyImmediately();
      return;
    }

    await _requestPermissions();
    _listenOnce();
    await _beginScan();
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (_removeStaleDevices()) {
        _scheduleScanNotify();
      }
    });
  }

  @override
  Future<void> refresh() async {
    await _beginScan();
  }

  @override
  Future<void> stop() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    _isScanning = false;
    _statusText = 'Scan paused';
    _notifyImmediately();
  }

  void _listenOnce() {
    if (_subscriptions.isNotEmpty) {
      return;
    }

    _subscriptions.add(
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          _statusText = _platformScanNote();
        } else {
          _statusText = 'Bluetooth is ${state.name}';
        }
        _notifyImmediately();
      }),
    );

    _subscriptions.add(
      FlutterBluePlus.isScanning.listen((isScanning) {
        _isScanning = isScanning;
        _notifyImmediately();
      }),
    );

    _subscriptions.add(
      FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            final device = _parser.parseScanResult(result);
            _deviceRanks.putIfAbsent(device.id, () => _nextDeviceRank++);
            _devices[device.id] = device;
          }
          final removedStaleDevices = _removeStaleDevices();
          if (results.isNotEmpty || removedStaleDevices) {
            _scheduleScanNotify();
          }
        },
        onError: (Object error) {
          _statusText = 'Scan error: $error';
          _notifyImmediately();
        },
      ),
    );
  }

  Future<void> _beginScan() async {
    try {
      _statusText = 'Scanning nearby BLE packets';
      _notifyImmediately();
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        continuousDivisor: 2,
        removeIfGone: const Duration(seconds: 14),
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
        androidCheckLocationServices: false,
      );
    } catch (error) {
      _statusText = 'Unable to scan: $error';
      _notifyImmediately();
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      return;
    }
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
      ].request();
      return;
    }
    if (Platform.isIOS) {
      await Permission.bluetooth.request();
    }
  }

  bool _removeStaleDevices() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 20));
    var removed = false;
    _devices.removeWhere((id, device) {
      final isStale = device.lastSeen.isBefore(cutoff);
      if (isStale) {
        removed = true;
        _deviceRanks.remove(id);
      }
      return isStale;
    });
    return removed;
  }

  void _scheduleScanNotify() {
    if (_pendingScanNotify != null) {
      return;
    }
    final now = DateTime.now();
    final lastNotifyAt = _lastScanNotifyAt;
    if (lastNotifyAt == null ||
        now.difference(lastNotifyAt) >= _scanUiUpdateInterval) {
      _lastScanNotifyAt = now;
      notifyListeners();
      return;
    }
    _pendingScanNotify = Timer(
      _scanUiUpdateInterval - now.difference(lastNotifyAt),
      () {
        _pendingScanNotify = null;
        _lastScanNotifyAt = DateTime.now();
        notifyListeners();
      },
    );
  }

  void _notifyImmediately() {
    _pendingScanNotify?.cancel();
    _pendingScanNotify = null;
    _lastScanNotifyAt = DateTime.now();
    notifyListeners();
  }

  String _platformScanNote() {
    if (!kIsWeb && Platform.isIOS) {
      return 'Scanning BLE packets; iOS hides raw iBeacon packets from generic BLE scans';
    }
    return 'Scanning nearby Eddystone, iBeacon, and BLE packets';
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _refreshTimer?.cancel();
    _pendingScanNotify?.cancel();
    super.dispose();
  }
}

class MemoryBeaconScanner extends BeaconScanner {
  MemoryBeaconScanner({
    List<BeaconDevice> devices = const [],
    bool isScanning = false,
    String statusText = 'Ready',
    bool isSupported = true,
  }) : _devices = devices,
       _isScanning = isScanning,
       _statusText = statusText,
       _isSupported = isSupported;

  List<BeaconDevice> _devices;
  bool _isScanning;
  final String _statusText;
  final bool _isSupported;

  @override
  List<BeaconDevice> get devices => _devices;

  @override
  bool get isScanning => _isScanning;

  @override
  String get statusText => _statusText;

  @override
  bool get isSupported => _isSupported;

  void replaceDevices(List<BeaconDevice> next) {
    _devices = next;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> start() async {
    _isScanning = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _isScanning = false;
    notifyListeners();
  }
}
