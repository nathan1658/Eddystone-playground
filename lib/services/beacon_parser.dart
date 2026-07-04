import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/beacon_device.dart';

class BeaconParser {
  static const int appleCompanyId = 0x004c;
  static const String eddystoneUuid = 'feaa';

  BeaconDevice parseScanResult(ScanResult result) {
    final data = result.advertisementData;
    final remoteId = result.device.remoteId.str;
    final name = data.advName;
    final seen = result.timeStamp;
    final iBeacon = _parseIBeacon(data.manufacturerData[appleCompanyId]);
    if (iBeacon != null) {
      return BeaconDevice(
        id: 'ibeacon:${iBeacon.uuid}:${iBeacon.major}:${iBeacon.minor}',
        kind: BeaconKind.iBeacon,
        remoteId: remoteId,
        displayName: name,
        identity: '${iBeacon.uuid}:${iBeacon.major}:${iBeacon.minor}',
        rssi: result.rssi,
        lastSeen: seen,
        txPower: iBeacon.measuredPower,
        uuid: iBeacon.uuid,
        major: iBeacon.major,
        minor: iBeacon.minor,
        raw: _hex(data.manufacturerData[appleCompanyId] ?? const []),
      );
    }

    final eddystone = _parseEddystone(data.serviceData);
    if (eddystone != null) {
      return BeaconDevice(
        id: eddystone.id,
        kind: eddystone.kind,
        remoteId: remoteId,
        displayName: name,
        identity: eddystone.identity,
        rssi: result.rssi,
        lastSeen: seen,
        txPower: eddystone.txPower,
        namespaceId: eddystone.namespaceId,
        instanceId: eddystone.instanceId,
        url: eddystone.url,
        telemetry: eddystone.telemetry,
        raw: eddystone.raw,
      );
    }

    return BeaconDevice(
      id: 'ble:$remoteId',
      kind: BeaconKind.ble,
      remoteId: remoteId,
      displayName: name,
      identity: remoteId,
      rssi: result.rssi,
      lastSeen: seen,
      txPower: data.txPowerLevel,
      raw: _rawSummary(data),
    );
  }

  _ParsedIBeacon? _parseIBeacon(List<int>? bytes) {
    if (bytes == null || bytes.length < 23) {
      return null;
    }
    if (bytes[0] != 0x02 || bytes[1] != 0x15) {
      return null;
    }

    final uuidBytes = bytes.sublist(2, 18);
    final uuid = [
      _hex(uuidBytes.sublist(0, 4)),
      _hex(uuidBytes.sublist(4, 6)),
      _hex(uuidBytes.sublist(6, 8)),
      _hex(uuidBytes.sublist(8, 10)),
      _hex(uuidBytes.sublist(10, 16)),
    ].join('-');
    return _ParsedIBeacon(
      uuid: uuid,
      major: _uint16(bytes, 18),
      minor: _uint16(bytes, 20),
      measuredPower: _int8(bytes[22]),
    );
  }

  _ParsedEddystone? _parseEddystone(Map<Guid, List<int>> serviceData) {
    for (final entry in serviceData.entries) {
      if (entry.key.str.toLowerCase() != eddystoneUuid) {
        continue;
      }
      final bytes = entry.value;
      if (bytes.length < 2) {
        return null;
      }
      final frameType = bytes[0];
      final txPower = _int8(bytes[1]);
      if (frameType == 0x00 && bytes.length >= 18) {
        final namespaceId = _hex(bytes.sublist(2, 12));
        final instanceId = _hex(bytes.sublist(12, 18));
        return _ParsedEddystone(
          id: 'eddystone-uid:$namespaceId:$instanceId',
          kind: BeaconKind.eddystoneUid,
          identity: '$namespaceId:$instanceId',
          txPower: txPower,
          namespaceId: namespaceId,
          instanceId: instanceId,
          raw: _hex(bytes),
        );
      }
      if (frameType == 0x10 && bytes.length >= 3) {
        final url = _decodeEddystoneUrl(bytes.sublist(2));
        return _ParsedEddystone(
          id: 'eddystone-url:$url',
          kind: BeaconKind.eddystoneUrl,
          identity: url,
          txPower: txPower,
          url: url,
          raw: _hex(bytes),
        );
      }
      if (frameType == 0x20 && bytes.length >= 14) {
        final voltage = _uint16(bytes, 2);
        final tempRaw = _uint16(bytes, 4);
        final temp = tempRaw / 256;
        final advCount = _uint32(bytes, 6);
        final uptime = _uint32(bytes, 10) / 10;
        final telemetry =
            '${voltage}mV, ${temp.toStringAsFixed(1)}C, $advCount adv, ${uptime.toStringAsFixed(1)}s';
        return _ParsedEddystone(
          id: 'eddystone-tlm:${_hex(bytes)}',
          kind: BeaconKind.eddystoneTlm,
          identity: telemetry,
          txPower: txPower,
          telemetry: telemetry,
          raw: _hex(bytes),
        );
      }
    }
    return null;
  }

  String _decodeEddystoneUrl(List<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    const schemes = ['http://www.', 'https://www.', 'http://', 'https://'];
    const expansions = [
      '.com/',
      '.org/',
      '.edu/',
      '.net/',
      '.info/',
      '.biz/',
      '.gov/',
      '.com',
      '.org',
      '.edu',
      '.net',
      '.info',
      '.biz',
      '.gov',
    ];
    final buffer = StringBuffer();
    final scheme = bytes.first;
    buffer.write(scheme < schemes.length ? schemes[scheme] : '');
    for (final byte in bytes.skip(1)) {
      if (byte < expansions.length) {
        buffer.write(expansions[byte]);
      } else if (byte >= 32 && byte <= 126) {
        buffer.writeCharCode(byte);
      }
    }
    return buffer.toString();
  }

  String _rawSummary(AdvertisementData data) {
    final manufacturers = data.manufacturerData.entries
        .map(
          (entry) => 'mfg ${entry.key.toRadixString(16)}=${_hex(entry.value)}',
        )
        .join(', ');
    final services = data.serviceData.entries
        .map((entry) => '${entry.key.str}=${_hex(entry.value)}')
        .join(', ');
    return [
      manufacturers,
      services,
    ].where((part) => part.isNotEmpty).join(' | ');
  }

  int _uint16(List<int> bytes, int offset) {
    return ((bytes[offset] & 0xff) << 8) | (bytes[offset + 1] & 0xff);
  }

  int _uint32(List<int> bytes, int offset) {
    return ((bytes[offset] & 0xff) << 24) |
        ((bytes[offset + 1] & 0xff) << 16) |
        ((bytes[offset + 2] & 0xff) << 8) |
        (bytes[offset + 3] & 0xff);
  }

  int _int8(int value) {
    return value > 127 ? value - 256 : value;
  }

  String _hex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _ParsedIBeacon {
  const _ParsedIBeacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.measuredPower,
  });

  final String uuid;
  final int major;
  final int minor;
  final int measuredPower;
}

class _ParsedEddystone {
  const _ParsedEddystone({
    required this.id,
    required this.kind,
    required this.identity,
    required this.raw,
    this.txPower,
    this.namespaceId,
    this.instanceId,
    this.url,
    this.telemetry,
  });

  final String id;
  final BeaconKind kind;
  final String identity;
  final String raw;
  final int? txPower;
  final String? namespaceId;
  final String? instanceId;
  final String? url;
  final String? telemetry;
}
