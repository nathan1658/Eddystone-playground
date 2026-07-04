import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/beacon_device.dart';
import 'beacon_advertiser.dart';
import 'beacon_scanner.dart';

class BeaconDiagnostics {
  BeaconDiagnostics({
    required BeaconScanner scanner,
    required BeaconAdvertiser advertiser,
  }) : _scanner = scanner,
       _advertiser = advertiser;

  static const mode = String.fromEnvironment('BEACON_DIAGNOSTIC_MODE');
  static const iBeaconUuid = 'e2c56db5-dffb-48d2-b060-d0f5a71096e0';
  static const iBeaconMajor = 4242;
  static const iBeaconMinor = 1701;
  static const eddystoneUrl = 'https://goo.gle';
  static const eddystoneNamespace = '00112233445566778899';
  static const eddystoneInstance = 'aabbccddeeff';
  static const measuredPower = -59;

  final BeaconScanner _scanner;
  final BeaconAdvertiser _advertiser;
  final Set<String> _seen = {};
  Timer? _scanTimeout;

  bool get enabled => mode.isNotEmpty;

  Future<void> start() async {
    if (!enabled) {
      return;
    }
    _log('mode=$mode');
    switch (mode) {
      case 'advertise_ibeacon':
        await _startIBeacon();
      case 'advertise_eddystone_url':
        await _startEddystoneUrl();
      case 'advertise_eddystone_uid':
        await _startEddystoneUid();
      case 'scan':
        _startScanWitness();
      default:
        _log('unknown_mode=$mode');
    }
  }

  Future<void> _startIBeacon() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    await _advertiser.startIBeacon(
      uuid: iBeaconUuid,
      major: iBeaconMajor,
      minor: iBeaconMinor,
      measuredPower: measuredPower,
    );
    _log(
      'advertising=ibeacon uuid=$iBeaconUuid major=$iBeaconMajor minor=$iBeaconMinor',
    );
  }

  Future<void> _startEddystoneUrl() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    await _advertiser.startEddystoneUrl(
      url: eddystoneUrl,
      measuredPower: measuredPower,
    );
    _log('advertising=eddystone_url url=$eddystoneUrl');
  }

  Future<void> _startEddystoneUid() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    await _advertiser.startEddystoneUid(
      namespaceId: eddystoneNamespace,
      instanceId: eddystoneInstance,
      measuredPower: measuredPower,
    );
    _log(
      'advertising=eddystone_uid namespace=$eddystoneNamespace instance=$eddystoneInstance',
    );
  }

  void _startScanWitness() {
    _scanner.addListener(_inspectScan);
    _scanTimeout = Timer.periodic(const Duration(seconds: 10), (_) {
      _log('scan_visible_count=${_scanner.devices.length}');
    });
    _inspectScan();
  }

  void _inspectScan() {
    for (final device in _scanner.devices) {
      if (_isDiagnosticIBeacon(device)) {
        _logSeen('ibeacon', device);
      }
      if (_isDiagnosticEddystoneUrl(device)) {
        _logSeen('eddystone_url', device);
      }
      if (_isDiagnosticEddystoneUid(device)) {
        _logSeen('eddystone_uid', device);
      }
    }
  }

  bool _isDiagnosticIBeacon(BeaconDevice device) {
    return device.kind == BeaconKind.iBeacon &&
        device.uuid?.toLowerCase() == iBeaconUuid &&
        device.major == iBeaconMajor &&
        device.minor == iBeaconMinor;
  }

  bool _isDiagnosticEddystoneUrl(BeaconDevice device) {
    return device.kind == BeaconKind.eddystoneUrl &&
        device.url?.toLowerCase() == eddystoneUrl;
  }

  bool _isDiagnosticEddystoneUid(BeaconDevice device) {
    return device.kind == BeaconKind.eddystoneUid &&
        device.namespaceId?.toLowerCase() == eddystoneNamespace &&
        device.instanceId?.toLowerCase() == eddystoneInstance;
  }

  void _logSeen(String protocol, BeaconDevice device) {
    if (!_seen.add('$protocol:${device.id}')) {
      return;
    }
    _log(
      'seen=$protocol id=${device.id} rssi=${device.rssi} remote=${device.remoteId}',
    );
  }

  void dispose() {
    if (enabled && mode == 'scan') {
      _scanner.removeListener(_inspectScan);
    }
    _scanTimeout?.cancel();
  }

  void _log(String message) {
    // Stable prefix for automated device-log verification.
    debugPrint('BEACON_DIAGNOSTIC $message');
  }
}
