import 'package:eddystone_playground/main.dart';
import 'package:eddystone_playground/models/beacon_device.dart';
import 'package:eddystone_playground/services/annotation_store.dart';
import 'package:eddystone_playground/services/beacon_advertiser.dart';
import 'package:eddystone_playground/services/beacon_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows scanner and advertiser modes', (tester) async {
    final scanner = MemoryBeaconScanner(
      devices: [
        BeaconDevice(
          id: 'ibeacon:00112233-4455-6677-8899-aabbccddeeff:1:2',
          kind: BeaconKind.iBeacon,
          remoteId: 'AA:BB:CC:DD:EE:FF',
          displayName: 'Lobby beacon',
          identity: '00112233-4455-6677-8899-aabbccddeeff:1:2',
          rssi: -62,
          lastSeen: DateTime.now(),
          uuid: '00112233-4455-6677-8899-aabbccddeeff',
          major: 1,
          minor: 2,
          txPower: -59,
        ),
      ],
      isScanning: true,
      statusText: 'Scanning in test',
    );

    await tester.pumpWidget(
      BeaconApp(
        scanner: scanner,
        annotationStore: MemoryAnnotationStore(),
        advertiser: const FakeBeaconAdvertiser(),
      ),
    );
    await tester.pump();

    expect(find.text('Eddystone playground'), findsOneWidget);
    expect(find.text('Lobby beacon'), findsOneWidget);
    expect(find.text('Scanning in test'), findsOneWidget);

    await tester.tap(find.text('Advertise').first);
    await tester.pumpAndSettle();

    expect(find.text('iBeacon'), findsWidgets);
    expect(find.text('Start advertising'), findsOneWidget);
  });

  testWidgets('keeps scan rows in scanner order', (tester) async {
    final now = DateTime(2026);
    final scanner = MemoryBeaconScanner(
      devices: [
        BeaconDevice(
          id: 'ble:first',
          kind: BeaconKind.ble,
          remoteId: 'AA:AA:AA:AA:AA:AA',
          displayName: 'First stable row',
          identity: 'AA:AA:AA:AA:AA:AA',
          rssi: -70,
          lastSeen: now,
        ),
        BeaconDevice(
          id: 'ble:second',
          kind: BeaconKind.ble,
          remoteId: 'BB:BB:BB:BB:BB:BB',
          displayName: 'Second stable row',
          identity: 'BB:BB:BB:BB:BB:BB',
          rssi: -42,
          lastSeen: now.add(const Duration(seconds: 10)),
        ),
      ],
      isScanning: true,
      statusText: 'Scanning in test',
    );

    await tester.pumpWidget(
      BeaconApp(
        scanner: scanner,
        annotationStore: MemoryAnnotationStore(),
        advertiser: const FakeBeaconAdvertiser(),
      ),
    );
    await tester.pump();

    final firstTop = tester.getTopLeft(find.text('First stable row')).dy;
    final secondTop = tester.getTopLeft(find.text('Second stable row')).dy;
    expect(firstTop, lessThan(secondTop));
  });
}
