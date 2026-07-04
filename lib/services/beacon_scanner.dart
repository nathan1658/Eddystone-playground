import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
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

  final BeaconParser _parser;
  final Map<String, BeaconDevice> _devices = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _refreshTimer;
  bool _isScanning = false;
  bool _isSupported = true;
  String _statusText = 'Starting Bluetooth scan';

  @override
  List<BeaconDevice> get devices {
    final sorted = _devices.values.toList()
      ..sort((a, b) {
        final bySeen = b.lastSeen.compareTo(a.lastSeen);
        if (bySeen != 0) {
          return bySeen;
        }
        return b.rssi.compareTo(a.rssi);
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
      notifyListeners();
      return;
    }

    await _requestPermissions();
    _listenOnce();
    await _beginScan();
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      _removeStaleDevices();
      notifyListeners();
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
    notifyListeners();
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
        notifyListeners();
      }),
    );

    _subscriptions.add(
      FlutterBluePlus.isScanning.listen((isScanning) {
        _isScanning = isScanning;
        notifyListeners();
      }),
    );

    _subscriptions.add(
      FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            final device = _parser.parseScanResult(result);
            _devices[device.id] = device;
          }
          _removeStaleDevices();
          notifyListeners();
        },
        onError: (Object error) {
          _statusText = 'Scan error: $error';
          notifyListeners();
        },
      ),
    );
  }

  Future<void> _beginScan() async {
    try {
      _statusText = 'Scanning nearby BLE packets';
      notifyListeners();
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        continuousDivisor: 2,
        removeIfGone: const Duration(seconds: 14),
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: false,
        androidCheckLocationServices: false,
      );
    } catch (error) {
      _statusText = 'Unable to scan: $error';
      notifyListeners();
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

  void _removeStaleDevices() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 20));
    _devices.removeWhere((_, device) => device.lastSeen.isBefore(cutoff));
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
  List<BeaconDevice> get devices => _devices.sortedByCompare(
    (device) => device.lastSeen,
    (a, b) => b.compareTo(a),
  );

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
