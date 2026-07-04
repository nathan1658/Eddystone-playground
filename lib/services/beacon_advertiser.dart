import 'package:flutter/services.dart';

enum AdvertiseMode { iBeacon, eddystoneUid, eddystoneUrl }

extension AdvertiseModeLabel on AdvertiseMode {
  String get label {
    return switch (this) {
      AdvertiseMode.iBeacon => 'iBeacon',
      AdvertiseMode.eddystoneUid => 'Eddystone UID',
      AdvertiseMode.eddystoneUrl => 'Eddystone URL',
    };
  }
}

class AdvertiseCapabilities {
  const AdvertiseCapabilities({
    required this.isSupported,
    required this.iBeacon,
    required this.eddystone,
    required this.platform,
    required this.message,
  });

  final bool isSupported;
  final bool iBeacon;
  final bool eddystone;
  final String platform;
  final String message;

  factory AdvertiseCapabilities.fromJson(Map<Object?, Object?> json) {
    return AdvertiseCapabilities(
      isSupported: json['isSupported'] as bool? ?? false,
      iBeacon: json['iBeacon'] as bool? ?? false,
      eddystone: json['eddystone'] as bool? ?? false,
      platform: json['platform'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
    );
  }
}

abstract class BeaconAdvertiser {
  Future<AdvertiseCapabilities> capabilities();

  Future<void> startIBeacon({
    required String uuid,
    required int major,
    required int minor,
    required int measuredPower,
  });

  Future<void> startEddystoneUid({
    required String namespaceId,
    required String instanceId,
    required int measuredPower,
  });

  Future<void> startEddystoneUrl({
    required String url,
    required int measuredPower,
  });

  Future<void> stop();
}

class MethodChannelBeaconAdvertiser implements BeaconAdvertiser {
  static const MethodChannel _channel = MethodChannel(
    'eddystone_playground/beacon_advertiser',
  );

  @override
  Future<AdvertiseCapabilities> capabilities() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'capabilities',
    );
    return AdvertiseCapabilities.fromJson(response ?? const {});
  }

  @override
  Future<void> startIBeacon({
    required String uuid,
    required int major,
    required int minor,
    required int measuredPower,
  }) {
    return _channel.invokeMethod<void>('startIBeacon', {
      'uuid': uuid,
      'major': major,
      'minor': minor,
      'measuredPower': measuredPower,
    });
  }

  @override
  Future<void> startEddystoneUid({
    required String namespaceId,
    required String instanceId,
    required int measuredPower,
  }) {
    return _channel.invokeMethod<void>('startEddystoneUid', {
      'namespaceId': namespaceId,
      'instanceId': instanceId,
      'measuredPower': measuredPower,
    });
  }

  @override
  Future<void> startEddystoneUrl({
    required String url,
    required int measuredPower,
  }) {
    return _channel.invokeMethod<void>('startEddystoneUrl', {
      'url': url,
      'measuredPower': measuredPower,
    });
  }

  @override
  Future<void> stop() {
    return _channel.invokeMethod<void>('stop');
  }
}

class FakeBeaconAdvertiser implements BeaconAdvertiser {
  const FakeBeaconAdvertiser({
    this.response = const AdvertiseCapabilities(
      isSupported: true,
      iBeacon: true,
      eddystone: true,
      platform: 'test',
      message: 'Ready',
    ),
  });

  final AdvertiseCapabilities response;

  @override
  Future<AdvertiseCapabilities> capabilities() async => response;

  @override
  Future<void> startEddystoneUid({
    required String namespaceId,
    required String instanceId,
    required int measuredPower,
  }) async {}

  @override
  Future<void> startEddystoneUrl({
    required String url,
    required int measuredPower,
  }) async {}

  @override
  Future<void> startIBeacon({
    required String uuid,
    required int major,
    required int minor,
    required int measuredPower,
  }) async {}

  @override
  Future<void> stop() async {}
}
