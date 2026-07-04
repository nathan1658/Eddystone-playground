import 'dart:math' as math;

enum BeaconKind { iBeacon, eddystoneUid, eddystoneUrl, eddystoneTlm, ble }

extension BeaconKindLabel on BeaconKind {
  String get label {
    return switch (this) {
      BeaconKind.iBeacon => 'iBeacon',
      BeaconKind.eddystoneUid => 'Eddystone UID',
      BeaconKind.eddystoneUrl => 'Eddystone URL',
      BeaconKind.eddystoneTlm => 'Eddystone TLM',
      BeaconKind.ble => 'BLE',
    };
  }
}

class BeaconDevice {
  const BeaconDevice({
    required this.id,
    required this.kind,
    required this.remoteId,
    required this.displayName,
    required this.identity,
    required this.rssi,
    required this.lastSeen,
    this.txPower,
    this.uuid,
    this.major,
    this.minor,
    this.namespaceId,
    this.instanceId,
    this.url,
    this.telemetry,
    this.raw,
  });

  final String id;
  final BeaconKind kind;
  final String remoteId;
  final String displayName;
  final String identity;
  final int rssi;
  final DateTime lastSeen;
  final int? txPower;
  final String? uuid;
  final int? major;
  final int? minor;
  final String? namespaceId;
  final String? instanceId;
  final String? url;
  final String? telemetry;
  final String? raw;

  String get title {
    if (displayName.trim().isNotEmpty) {
      return displayName;
    }
    return kind.label;
  }

  String get subtitle {
    return switch (kind) {
      BeaconKind.iBeacon => '$uuid | major $major | minor $minor',
      BeaconKind.eddystoneUid => '$namespaceId / $instanceId',
      BeaconKind.eddystoneUrl => url ?? identity,
      BeaconKind.eddystoneTlm => telemetry ?? identity,
      BeaconKind.ble => identity,
    };
  }

  double? get approximateDistanceMeters {
    final measuredPower = txPower;
    if (measuredPower == null || measuredPower == 0) {
      return null;
    }
    final ratio = rssi / measuredPower;
    if (ratio < 1) {
      return math.pow(ratio, 10).toDouble();
    }
    return 0.89976 * math.pow(ratio, 7.7095) + 0.111;
  }
}
