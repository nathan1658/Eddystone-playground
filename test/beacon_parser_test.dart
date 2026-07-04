import 'package:eddystone_playground/models/beacon_device.dart';
import 'package:eddystone_playground/services/beacon_parser.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = BeaconParser();

  test('parses iBeacon manufacturer data', () {
    final result = _scanResult(
      manufacturerData: {
        BeaconParser.appleCompanyId: [
          0x02,
          0x15,
          0x00,
          0x11,
          0x22,
          0x33,
          0x44,
          0x55,
          0x66,
          0x77,
          0x88,
          0x99,
          0xaa,
          0xbb,
          0xcc,
          0xdd,
          0xee,
          0xff,
          0x00,
          0x2a,
          0x00,
          0x07,
          0xc5,
        ],
      },
    );

    final beacon = parser.parseScanResult(result);

    expect(beacon.kind, BeaconKind.iBeacon);
    expect(beacon.uuid, '00112233-4455-6677-8899-aabbccddeeff');
    expect(beacon.major, 42);
    expect(beacon.minor, 7);
    expect(beacon.txPower, -59);
  });

  test('parses Eddystone URL service data', () {
    final result = _scanResult(
      serviceData: {
        Guid('feaa'): [0x10, 0xc5, 0x03, ...'openai'.codeUnits, 0x07],
      },
    );

    final beacon = parser.parseScanResult(result);

    expect(beacon.kind, BeaconKind.eddystoneUrl);
    expect(beacon.url, 'https://openai.com');
    expect(beacon.txPower, -59);
  });

  test('falls back to BLE when no beacon frame is present', () {
    final result = _scanResult(
      manufacturerData: {
        0x1234: [1, 2, 3],
      },
    );

    final beacon = parser.parseScanResult(result);

    expect(beacon.kind, BeaconKind.ble);
    expect(beacon.id, 'ble:AA:BB:CC:DD:EE:FF');
  });
}

ScanResult _scanResult({
  Map<int, List<int>> manufacturerData = const {},
  Map<Guid, List<int>> serviceData = const {},
}) {
  return ScanResult(
    device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF'),
    advertisementData: AdvertisementData(
      advName: 'Beacon',
      txPowerLevel: null,
      appearance: null,
      connectable: false,
      manufacturerData: manufacturerData,
      serviceData: serviceData,
      serviceUuids: const [],
    ),
    rssi: -61,
    timeStamp: DateTime.now(),
  );
}
